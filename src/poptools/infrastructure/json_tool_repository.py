from __future__ import annotations

from poptools.domain.models import ToolDefinition, ToolOrigin, ToolSection
from poptools.domain.repositories import ToolRepository
from poptools.infrastructure.json_file_storage import JsonFileStorage
from poptools.paths import AppPaths


class JsonToolRepository(ToolRepository):
    """JSON implementation of the user tool repository."""

    def __init__(self, paths: AppPaths) -> None:
        self.paths = paths
        self.paths.ensure()
        self.files = JsonFileStorage(paths.backups_dir)

    def list_tools(self) -> list[ToolDefinition]:
        tools: list[ToolDefinition] = []
        for folder in (self.paths.overrides_dir, self.paths.custom_dir):
            for file_path in sorted(folder.glob("*.json")):
                try:
                    tool = ToolDefinition.model_validate_json(file_path.read_text("utf-8"))
                    # The containing folder is the persistence authority. Older
                    # exports can contain custom scripts whose metadata still says
                    # ``override``/``local``. Treating that metadata literally makes
                    # edits land in tools/overrides while the original custom file
                    # wins on reload, and makes deletion appear to do nothing.
                    if folder == self.paths.custom_dir and (
                        tool.origin != ToolOrigin.CUSTOM
                        or tool.section != ToolSection.CUSTOM
                        or not tool.editable
                    ):
                        tool = tool.model_copy(
                            update={
                                "origin": ToolOrigin.CUSTOM,
                                "section": ToolSection.CUSTOM,
                                "editable": True,
                            }
                        )
                        self.files.write(file_path, tool.model_dump(mode="json"))
                    migrated_path = file_path.with_name(f"{tool.id}.json")
                    if migrated_path != file_path:
                        if migrated_path.exists():
                            self.files.backup(file_path, suffix="legacy-conflict")
                            file_path.unlink()
                            continue
                        self.files.write(migrated_path, tool.model_dump(mode="json"))
                        file_path.unlink()
                    tools.append(tool)
                except Exception:
                    # Quarantine the invalid source after preserving one recoverable copy.
                    self.files.backup(file_path, suffix="invalid")
                    file_path.unlink(missing_ok=True)
        return tools

    def save_tool(self, tool: ToolDefinition) -> None:
        target_dir = (
            self.paths.custom_dir if tool.origin == ToolOrigin.CUSTOM else self.paths.overrides_dir
        )
        target = target_dir / f"{tool.id}.json"
        self.files.write(target, tool.model_dump(mode="json"))

    def remove_override(self, tool_id: str) -> bool:
        target = self.paths.overrides_dir / f"{tool_id}.json"
        if not target.exists():
            return False
        self.files.backup(target, suffix="reset")
        target.unlink()
        return True

    def delete_tool(self, tool_id: str) -> bool:
        target = self.paths.custom_dir / f"{tool_id}.json"
        if not target.exists():
            return False
        self.files.backup(target, suffix="deleted")
        target.unlink()
        # Releases affected by the imported-custom metadata bug may have written
        # attempted edits or delete markers to overrides under the same id. Once
        # the user deletes the custom tool, that stale file must not resurrect it.
        stale_override = self.paths.overrides_dir / f"{tool_id}.json"
        if stale_override.exists():
            self.files.backup(stale_override, suffix="stale-override")
            stale_override.unlink()
        return True
