from pathlib import Path

from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path


def test_override_and_reset(tmp_path: Path) -> None:
    repository = JsonToolRepository(AppPaths(tmp_path))
    registry = ToolRegistry(resource_path("tools"), repository)
    original = registry.get("preset.json")
    assert original is not None
    registry.save_override(
        original.id,
        title="新的名称",
        description=original.description,
        kind=original.executor.kind,
        command=original.executor.command,
        args=original.executor.args,
    )
    assert registry.get(original.id).title == "新的名称"  # type: ignore[union-attr]
    assert registry.reset(original.id) is True
    assert registry.get(original.id).title == original.title  # type: ignore[union-attr]


def test_preloaded_llm_log_analyzer_is_not_registered(tmp_path: Path) -> None:
    repository = JsonToolRepository(AppPaths(tmp_path))
    registry = ToolRegistry(resource_path("tools"), repository)

    assert registry.get("logs.llm") is None
