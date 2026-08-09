from pathlib import Path

from poptools.domain.models import (
    ExecutorDefinition,
    ExecutorKind,
    ToolDefinition,
    ToolOrigin,
    ToolSection,
)
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path


def test_custom_command_is_parameterized_and_deletable(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    repository = JsonToolRepository(paths)
    registry = ToolRegistry(resource_path("tools"), repository)

    created = registry.create_custom(
        title="密码命令",
        description="测试动态参数",
        kind=ExecutorKind.POWERSHELL,
        command="adb shell ${输入密码}",
        icon="key",
    )

    assert created.section == ToolSection.CUSTOM
    assert created.origin == ToolOrigin.CUSTOM
    assert created.presentation.icon == "key"
    assert [parameter.id for parameter in created.parameters] == ["输入密码"]
    assert paths.custom_dir.joinpath(f"{created.id}.json").exists()

    updated = registry.update_tool(
        created.id,
        title=created.title,
        description=created.description,
        kind=created.executor.kind,
        command="adb shell ${输入密码} ${动作}",
        args=[],
        icon="build",
    )
    assert updated.origin == ToolOrigin.CUSTOM
    assert updated.presentation.icon == "build"
    assert [parameter.id for parameter in updated.parameters] == ["输入密码", "动作"]

    assert registry.delete(created.id) is True
    assert registry.get(created.id) is None
    assert not paths.custom_dir.joinpath(f"{created.id}.json").exists()
    assert list(paths.backups_dir.glob(f"{created.id}.json.*.deleted"))


def test_custom_section_is_preserved(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    repository = JsonToolRepository(paths)
    repository.save_tool(
        ToolDefinition(
            id="custom.legacy",
            origin=ToolOrigin.CUSTOM,
            section=ToolSection.CUSTOM,
            title="旧版命令",
            executor=ExecutorDefinition(kind=ExecutorKind.POWERSHELL, command="echo legacy"),
        )
    )

    loaded = JsonToolRepository(paths).list_tools()

    assert loaded[0].section == ToolSection.CUSTOM
