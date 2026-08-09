from __future__ import annotations

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from poptools.infrastructure.android_device_service import (
    AndroidDeviceService,
    AndroidProcessService,
)
from poptools.infrastructure.config_store import ConfigStore


class AndroidController(QObject):
    """Own global Android device selection and asynchronous process discovery."""

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
        self._preferred_device = config_store.preferred_android_device()
        self._selected_device = ""
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

    @Property(str, notify=stateChanged)
    def selectedAndroidDevice(self) -> str:
        return self._selected_device

    @Property(str, notify=stateChanged)
    def selectedAndroidDeviceLabel(self) -> str:
        for device in self._device_service.devices:
            if device.serial == self._selected_device:
                return device.label
        return "未检测到 Android 设备"

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

    @Slot()
    def refreshAndroidProcesses(self) -> None:
        self._process_service.refresh(self._selected_device)

    @Slot(str)
    def selectAndroidDevice(self, serial: str) -> None:
        available = {device.serial for device in self._device_service.devices}
        if serial not in available or serial == self._selected_device:
            return
        self._selected_device = serial
        self._preferred_device = serial
        self.config_store.set_preferred_android_device(serial)
        self.stateChanged.emit()
        self.refreshAndroidProcesses()

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
        available = [device.serial for device in self._device_service.devices]
        selected = self._selected_device
        if selected not in available:
            if self._preferred_device in available:
                selected = self._preferred_device
            else:
                selected = available[0] if available else ""
        self._selected_device = selected
        if selected and selected != self._preferred_device:
            self._preferred_device = selected
            self.config_store.set_preferred_android_device(selected)
        self.stateChanged.emit()
        self.refreshAndroidProcesses()
