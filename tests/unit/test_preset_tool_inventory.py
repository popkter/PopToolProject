from pathlib import Path

from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path


def test_only_supported_preset_tools_are_built_in(tmp_path: Path) -> None:
    registry = ToolRegistry(
        resource_path("tools"),
        JsonToolRepository(AppPaths(tmp_path)),
    )
    removed_ids = {
        "local.android.open_settings",
        "local.android.open_speech_debug",
        "local.android.send_asr",
        "local.android.sync_time",
        "local.android.update_exg",
        "local.android.exg_screen",
    }

    assert registry.for_section("custom") == []
    assert "preset.android.scrcpy" in {
        tool.id for tool in registry.for_section("preset")
    }
    assert all(registry.get(tool_id) is None for tool_id in removed_ids)
