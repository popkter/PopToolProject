from __future__ import annotations

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from poptools.infrastructure.android_device_service import (
    AndroidDeviceService,
    AndroidProcessService,
)
from poptools.infrastructure.config_store import ConfigStore


class AndroidController(QObject):
    """Share discovery while keeping device preferences isolated by tool ID."""

    stateChanged = Signal()

    def __init__(
        self,
        config_store: ConfigStore,
        device_service: AndroidDeviceService | None = None,
        process_service: AndroidProcessService | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.config_store = config_store
        self._device_service = device_service or AndroidDeviceService(self)
        self._process_service = process_service or AndroidProcessService(self)
        self._tool_devices = config_store.android_tool_devices()
        self._manual_device_refreshing = False
        self._device_service.devicesChanged.connect(self._on_devices_changed)
        self._device_service.refreshingChanged.connect(self._on_device_refreshing_changed)
        self._process_service.processesChanged.connect(self.stateChanged)
        self._process_service.refreshingChanged.connect(self.stateChanged)
        self._refresh_timer = QTimer(self)
        self._refresh_timer.setInterval(5000)
        self._refresh_timer.timeout.connect(self._refresh_android_devices_silently)
        self._refresh_timer.start()
        self._on_devices_changed()
        # The service already starts work asynchronously. Calling it directly avoids
        # leaving a context-free singleShot callback behind when a short-lived
        # controller is destroyed (notably in tests and settings-only processes).
        self._refresh_android_devices_silently()

    @Property("QVariantList", notify=stateChanged)
    def androidDevices(self) -> list[dict[str, str]]:
        return [device.to_qml() for device in self._device_service.devices]

    @Property("QVariantList", notify=stateChanged)
    def androidProcesses(self) -> list[dict[str, str]]:
        return self._process_service.processes

    @Slot(str, result="QVariantMap")
    def deviceForTool(self, tool_id: str) -> dict[str, object]:
        serial = self._tool_devices.get(tool_id, "")
        devices = self._device_service.devices
        if tool_id and not serial and len(devices) == 1:
            serial = devices[0].serial
            self._tool_devices[tool_id] = serial
            self.config_store.set_android_tool_device(tool_id, serial)
        device = next((d for d in devices if d.serial == serial), None)
        return {
            "serial": serial,
            "available": device is not None,
            "label": device.label if device else f"{serial} · 不可用" if serial
            else "请选择 Android 设备" if devices else "未检测到 Android 设备",
        }

    def available_device_for_tool(self, tool_id: str) -> str:
        state = self.deviceForTool(tool_id)
        return str(state["serial"]) if state["available"] else ""

    @Property(bool, notify=stateChanged)
    def androidDeviceRefreshing(self) -> bool:
        return self._manual_device_refreshing and self._device_service.refreshing

    @Slot()
    def refreshAndroidDevices(self) -> None:
        """Refresh from an explicit user action and expose its progress to QML."""
        already_refreshing = self._device_service.refreshing
        self._manual_device_refreshing = True
        self._device_service.refresh()
        if not self._device_service.refreshing:
            self._manual_device_refreshing = False
        elif already_refreshing:
            self.stateChanged.emit()

    @Slot(str)
    def refreshAndroidProcesses(self, serial: str) -> None:
        self._process_service.refresh(serial)

    @Slot(str, str)
    def selectDeviceForTool(self, tool_id: str, serial: str) -> None:
        available = {device.serial for device in self._device_service.devices}
        if not tool_id or serial not in available or serial == self._tool_devices.get(tool_id):
            return
        self._tool_devices[tool_id] = serial
        self.config_store.set_android_tool_device(tool_id, serial)
        self.stateChanged.emit()

    def forget_tool(self, tool_id: str) -> None:
        self._tool_devices.pop(tool_id, None)
        self.config_store.set_android_tool_device(tool_id, "")
        self.stateChanged.emit()

    def stopAutoRefresh(self) -> None:
        self._refresh_timer.stop()

    def _refresh_android_devices_silently(self) -> None:
        """Poll devices without publishing a transient scanning state to the UI."""
        self._device_service.refresh()

    def _on_device_refreshing_changed(self) -> None:
        if not self._manual_device_refreshing:
            return
        if not self._device_service.refreshing:
            self._manual_device_refreshing = False
        self.stateChanged.emit()

    def _on_devices_changed(self) -> None:
        self.stateChanged.emit()
