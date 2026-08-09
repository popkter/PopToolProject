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


def test_sort_popup_and_long_press_drag_are_wired_in_qml() -> None:
    qml_root = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"
    main = (qml_root / "Main.qml").read_text(encoding="utf-8")
    button = (qml_root / "components" / "ToolSortButton.qml").read_text(encoding="utf-8")
    item = (qml_root / "components" / "ToolListItem.qml").read_text(encoding="utf-8")

    assert "ToolSortButton {" in main
    assert "appController.moveTool(parent.toolId, targetIndex)" in main
    assert "onPressAndHold" in item
    assert 'background: AppPopupSurface { }' in button
    for mode in ("added_time", "name", "usage", "custom"):
        assert f'"value": "{mode}"' in button
