from pathlib import Path

import pytest

from poptools.infrastructure.android_device_service import AndroidDeviceService
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import AndroidController, AppController


class NoopAndroidDeviceService(AndroidDeviceService):
    def refresh(self) -> None:
        pass


def make_controller(tmp_path: Path) -> tuple[AppController, ConfigStore, ToolRegistry]:
    paths = AppPaths(tmp_path)
    store = ConfigStore(paths)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    coordinator = ExecutionCoordinator(
        ExecutionManager(paths),
        store.max_parallel(),
    )
    android = AndroidController(store, NoopAndroidDeviceService())
    android.stopAutoRefresh()
    controller = AppController(
        registry,
        coordinator,
        store,
        android,
    )
    return controller, store, registry


def visible_ids(controller: AppController) -> list[str]:
    return [tool.id for tool in controller._tools_model._tools]  # noqa: SLF001


def test_sort_mode_order_and_usage_are_persisted(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.tool_sort_mode() == "added_time"
    store.set_tool_sort_mode("usage")
    store.set_tool_order(["two", "one", "two"])
    assert store.increment_tool_usage("one") == 1
    assert store.increment_tool_usage("one") == 2

    reloaded = ConfigStore(AppPaths(tmp_path))
    assert reloaded.tool_sort_mode() == "usage"
    assert reloaded.tool_order() == ["two", "one"]
    assert reloaded.tool_usage_counts() == {"one": 2}

    with pytest.raises(ValueError, match="排序"):
        store.set_tool_sort_mode("unknown")


def test_controller_sorts_by_name_usage_and_dragged_custom_order(tmp_path: Path) -> None:
    controller, store, registry = make_controller(tmp_path)
    zebra = registry.create_custom(
        title="Zebra",
        description="",
        kind="powershell",
        command="Write-Output zebra",
    )
    alpha = registry.create_custom(
        title="Alpha",
        description="",
        kind="powershell",
        command="Write-Output alpha",
    )
    controller._refresh(select_id=zebra.id)  # noqa: SLF001

    assert controller.setToolSortMode("name") is True
    ids = visible_ids(controller)
    assert ids.index(alpha.id) < ids.index(zebra.id)

    store.increment_tool_usage(zebra.id)
    store.increment_tool_usage(zebra.id)
    assert controller.setToolSortMode("usage") is True
    assert visible_ids(controller)[0] == zebra.id

    assert controller.moveTool(alpha.id, 0) is False
    assert controller.setToolSortMode("custom") is True
    assert controller.moveTool(alpha.id, 0) is True
    assert controller.toolSortMode == "custom"
    assert visible_ids(controller)[0] == alpha.id

    reloaded, _, _ = make_controller(tmp_path)
    assert reloaded.toolSortMode == "custom"
    assert visible_ids(reloaded)[0] == alpha.id


def test_controller_filters_custom_tools_for_the_grid(tmp_path: Path) -> None:
    controller, _, registry = make_controller(tmp_path)
    registry.create_custom(
        title="Network Probe",
        description="Checks Android connectivity",
        kind="powershell",
        command="Write-Output network",
    )
    registry.create_custom(
        title="Collect Logs",
        description="Exports device diagnostics",
        kind="batch",
        command="echo logs",
    )
    controller._refresh()  # noqa: SLF001

    controller.setToolSearchQuery("android")
    assert [tool.title for tool in controller._tools_model._display_tools] == [  # noqa: SLF001
        "Network Probe"
    ]

    controller.setToolSearchQuery("")
    assert len(controller._tools_model._display_tools) == 2  # noqa: SLF001


def test_custom_tool_selection_can_be_cleared_without_stopping_the_tool(
    tmp_path: Path,
) -> None:
    controller, _, registry = make_controller(tmp_path)
    tool = registry.create_custom(
        title="Selectable",
        description="",
        kind="powershell",
        command="Write-Output selected",
    )
    controller._refresh()  # noqa: SLF001

    controller.selectTool(tool.id)
    assert controller.selectedTool["id"] == tool.id

    controller.clearToolSelection()
    assert controller.selectedTool == {}
    assert controller._tools_model._selected_id == ""  # noqa: SLF001


def test_running_custom_tools_are_temporarily_pinned_without_changing_order(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    controller, store, registry = make_controller(tmp_path)
    first = registry.create_custom(
        title="First", description="", kind="powershell", command="Write-Output first"
    )
    second = registry.create_custom(
        title="Second", description="", kind="powershell", command="Write-Output second"
    )
    controller.setToolSortMode("custom")
    store.set_tool_order([first.id, second.id])
    controller._refresh(select_id=first.id)  # noqa: SLF001
    original = visible_ids(controller)

    monkeypatch.setattr(
        controller.execution_coordinator, "running", lambda tool_id: tool_id == second.id
    )
    controller._refresh(select_id=first.id)  # noqa: SLF001
    assert visible_ids(controller)[0] == second.id

    monkeypatch.setattr(controller.execution_coordinator, "running", lambda _tool_id: False)
    controller._refresh(select_id=first.id)  # noqa: SLF001
    assert visible_ids(controller) == original
    assert store.tool_order() == [first.id, second.id]


def test_running_refresh_preserves_the_selected_tool_parameter_state(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    controller, _, registry = make_controller(tmp_path)
    tool = registry.create_custom(
        title="Input tool",
        description="",
        kind="powershell",
        command="Write-Output ${value}",
    )
    controller.selectTool(tool.id)
    selection_notifications: list[bool] = []
    running_notifications: list[bool] = []
    controller.selectedToolChanged.connect(lambda: selection_notifications.append(True))
    controller.runningChanged.connect(lambda: running_notifications.append(True))
    monkeypatch.setattr(
        controller.execution_coordinator,
        "running",
        lambda tool_id: tool_id == tool.id,
    )

    controller._on_execution_running_changed(tool.id, True)  # noqa: SLF001

    assert controller.selectedTool["id"] == tool.id
    assert selection_notifications == []
    assert running_notifications == [True]


def test_name_sort_uses_full_pinyin_for_chinese_and_latin_names() -> None:
    names = ["发送ASR", "法国", "Fable", "飞行", "发报机"]

    assert sorted(names, key=AppController._name_sort_key) == [  # noqa: SLF001
        "发报机",
        "Fable",
        "法国",
        "发送ASR",
        "飞行",
    ]
    assert AppController._name_sort_key("发送ASR") == "fasongasr"  # noqa: SLF001


def test_tray_keeps_preset_tools_separate_from_recent_custom_tools(tmp_path: Path) -> None:
    controller, store, registry = make_controller(tmp_path)
    custom = registry.create_custom(
        title="Custom tool",
        description="",
        kind="powershell",
        command="Write-Output custom",
    )
    controller._refresh(select_id=custom.id)  # noqa: SLF001
    store.record_tool_recent("preset.json")
    store.record_tool_recent(custom.id)

    assert [item["toolId"] for item in controller.getRecentTools()] == [custom.id]

    preset_ids = {item["toolId"] for item in controller.getPresetTools()}
    assert "preset.json" in preset_ids
    assert "preset.timestamp" in preset_ids
    assert "preset.colors" in preset_ids
    assert "preset.android.recording" in preset_ids
    assert "preset.android.scrcpy" not in preset_ids


def test_tray_preset_opens_dialog_but_scrcpy_is_rejected(tmp_path: Path) -> None:
    controller, _, _ = make_controller(tmp_path)
    requested: list[str] = []
    controller.recentToolDialogRequested.connect(requested.append)

    controller.openPresetToolFromTray("preset.json")
    controller.openPresetToolFromTray("preset.android.scrcpy")

    assert requested == ["preset.json"]
    assert controller.selectedTool["id"] == "preset.json"


def test_sort_popup_and_long_press_drag_are_wired_in_qml() -> None:
    qml_root = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"
    main = (qml_root / "Main.qml").read_text(encoding="utf-8")
    button = (qml_root / "components" / "ToolSortButton.qml").read_text(encoding="utf-8")
    item = (qml_root / "components" / "ToolListItem.qml").read_text(encoding="utf-8")

    assert "ToolSortButton {" in main
    assert "appController.moveTool(parent.toolId, targetIndex)" in main
    assert "onPressAndHold" in item
    assert "property bool running: false" in item
    assert "visible: root.running" in item
    assert "color: Theme.success" in item
    assert "running: parent.running" in main
    assert "background: AppPopupSurface { }" in button
    for mode in ("added_time", "name", "usage", "custom"):
        assert f'"value": "{mode}"' in button
