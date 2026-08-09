from pathlib import Path

from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path


def test_user_created_custom_command_can_be_deleted(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    created = registry.create_custom(
        title="临时命令", description="", kind="powershell", command="Write-Output ok"
    )

    assert registry.delete(created.id) is True
    assert all(tool.id != created.id for tool in registry.for_section("custom"))

    reloaded = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    assert reloaded.get(created.id) is None
