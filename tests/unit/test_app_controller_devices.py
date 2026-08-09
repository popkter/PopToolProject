from pathlib import Path
from typing import Any

from poptools.infrastructure.android_device_service import (
    AndroidDevice,
    AndroidDeviceService,
    AndroidProcessService,
)
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import AndroidController, AppController


class StaticAndroidDeviceService(AndroidDeviceService):
    def __init__(self) -> None:
        super().__init__()
        self._devices = [AndroidDevice(serial="emulator-5554", model="Pixel_8_Pro")]

    def refresh(self) -> None:
        pass


class NoopAndroidProcessService(AndroidProcessService):
    def refresh(self, _serial: str) -> None:
        pass


def build_controller(
    paths: AppPaths,
    config: ConfigStore,
    registry: ToolRegistry,
) -> AppController:
    execution = ExecutionManager(paths)
    coordinator = ExecutionCoordinator(execution, config.max_parallel())
    android = AndroidController(
        config,
        StaticAndroidDeviceService(),
        NoopAndroidProcessService(),
    )
    android.stopAutoRefresh()
    return AppController(registry, coordinator, config, android)


def test_controller_uses_one_global_device_for_local_adb_tools(
    tmp_path: Path,
    monkeypatch: Any,
) -> None:
    paths = AppPaths(tmp_path)
    config = ConfigStore(paths)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    controller = build_controller(paths, config, registry)
    captured: dict[str, Any] = {}

    def start(_tool: Any, values: dict[str, Any], _serial: str = "") -> bool:
        captured.update(values)
        return True

    monkeypatch.setattr(controller.execution_coordinator, "start", start)
    adb_tool = registry.create_custom(
        title="ADB 命令",
        description="测试全局设备注入",
        kind="powershell",
        command="adb shell echo ok",
    )
    controller.selectTool(adb_tool.id)

    assert controller.android_controller.selectedAndroidDevice == "emulator-5554"
    assert all(item["kind"] != "android_device" for item in controller.selectedTool["parameters"])
    assert controller.runSelected({}) is True
    assert captured["device"] == "emulator-5554"
    assert captured["__android_device__"] == "emulator-5554"
    assert config.preferred_android_device() == "emulator-5554"

    non_adb = registry.create_custom(
        title="普通命令",
        description="不使用 Android 设备",
        kind="powershell",
        command="Write-Output ${device}",
    )
    controller.selectTool(non_adb.id)
    captured.clear()
    assert controller.runSelected({"device": "manual-value"}) is True
    assert captured["device"] == "manual-value"
    assert "__android_device__" not in captured


def test_controller_starts_scrcpy_for_the_selected_global_device(
    tmp_path: Path,
    monkeypatch: Any,
) -> None:
    paths = AppPaths(tmp_path)
    config = ConfigStore(paths)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    controller = build_controller(paths, config, registry)
    captured: list[str] = []

    def start(serial: str) -> bool:
        captured.append(serial)
        return True

    monkeypatch.setattr(
        controller.execution_coordinator._scrcpy,  # noqa: SLF001
        "start",
        start,
    )
    controller.selectTool("preset.android.scrcpy")

    assert controller.android_controller.selectedAndroidDevice == "emulator-5554"
    assert controller.runSelected({}) is True
    assert captured == ["emulator-5554"]
