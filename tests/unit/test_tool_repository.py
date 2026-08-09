from __future__ import annotations

import json
from pathlib import Path

from poptools.domain.models import ToolDefinition, ToolOrigin, ToolSection
from poptools.domain.repositories import ToolRepository
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path


class MemoryToolRepository:
    def __init__(self) -> None:
        self.tools: dict[str, ToolDefinition] = {}

    def list_tools(self) -> list[ToolDefinition]:
        return list(self.tools.values())

    def save_tool(self, tool: ToolDefinition) -> None:
        self.tools[tool.id] = tool

    def remove_override(self, tool_id: str) -> bool:
        tool = self.tools.get(tool_id)
        if tool is None or tool.origin != ToolOrigin.OVERRIDE:
            return False
        del self.tools[tool_id]
        return True

    def delete_tool(self, tool_id: str) -> bool:
        tool = self.tools.get(tool_id)
        if tool is None or tool.origin != ToolOrigin.CUSTOM:
            return False
        del self.tools[tool_id]
        return True


def test_registry_depends_on_repository_protocol() -> None:
    repository = MemoryToolRepository()
    assert isinstance(repository, ToolRepository)

    registry = ToolRegistry(resource_path("tools"), repository)
    original = registry.get("preset.json")
    assert original is not None

    registry.save_override(
        original.id,
        title="协议仓库",
        description=original.description,
        kind=original.executor.kind,
        command=original.executor.command,
        args=original.executor.args,
    )

    assert repository.tools[original.id].title == "协议仓库"


def test_json_repository_keeps_existing_file_layout(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    repository = JsonToolRepository(paths)
    registry = ToolRegistry(resource_path("tools"), repository)
    original = registry.get("preset.json")
    assert original is not None

    registry.save_override(
        original.id,
        title="JSON 覆盖",
        description=original.description,
        kind=original.executor.kind,
        command=original.executor.command,
        args=original.executor.args,
    )

    expected = paths.overrides_dir / f"{original.id}.json"
    assert expected.exists()
    reloaded = JsonToolRepository(paths).list_tools()
    assert [tool.title for tool in reloaded] == ["JSON 覆盖"]


def test_json_repository_renames_legacy_preset_override_file(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    repository = JsonToolRepository(paths)
    legacy = paths.overrides_dir / "online.json.json"
    legacy.write_text(
        json.dumps(
            {
                "id": "online.json",
                "origin": "override",
                "section": "online",
                "title": "旧版 JSON 覆盖",
                "executor": {"kind": "internal", "command": "json"},
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    tools = repository.list_tools()

    assert [(tool.id, tool.section) for tool in tools] == [
        ("preset.json", ToolSection.PRESET)
    ]
    assert not legacy.exists()
    assert (paths.overrides_dir / "preset.json.json").exists()


def test_invalid_tool_is_backed_up_and_quarantined_once(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    repository = JsonToolRepository(paths)
    invalid = paths.custom_dir / "broken.json"
    invalid.write_text("{not-json", encoding="utf-8")

    assert repository.list_tools() == []
    assert not invalid.exists()
    backups = list(paths.backups_dir.glob("broken.json.*.invalid"))
    assert len(backups) == 1

    assert repository.list_tools() == []
    assert list(paths.backups_dir.glob("broken.json.*.invalid")) == backups
