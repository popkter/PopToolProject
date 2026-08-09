from __future__ import annotations

import shutil
from dataclasses import dataclass

from PySide6.QtCore import QObject, QTimer, Signal

from poptools.infrastructure.background_process import BackgroundProcess
from poptools.paths import bundled_adb_path


@dataclass(frozen=True, slots=True)
class AndroidDevice:
    serial: str
    model: str = ""
    product: str = ""
    device: str = ""

    @property
    def label(self) -> str:
        name = self.model.replace("_", " ") if self.model else self.product or self.serial
        return f"{name} · {self.serial}" if name != self.serial else self.serial

    def to_qml(self) -> dict[str, str]:
        return {
            "serial": self.serial,
            "label": self.label,
            "model": self.model,
            "status": "已连接",
        }


def parse_adb_devices(output: str) -> list[AndroidDevice]:
    """Parse connected devices from ``adb devices -l`` output."""

    devices: list[AndroidDevice] = []
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("List of devices attached"):
            continue
        parts = line.split()
        if len(parts) < 2 or parts[1] != "device":
            continue
        details = {
            key: value
            for token in parts[2:]
            if ":" in token
            for key, value in [token.split(":", maxsplit=1)]
        }
        devices.append(
            AndroidDevice(
                serial=parts[0],
                model=details.get("model", ""),
                product=details.get("product", ""),
                device=details.get("device", ""),
            )
        )
    return devices



def parse_android_processes(output: str) -> list[dict[str, str]]:
    """Parse application-like processes from ``adb shell ps -A`` output."""
    processes: dict[str, dict[str, str]] = {}
    for raw_line in output.splitlines()[1:]:
        fields = raw_line.split()
        pid_index = next((index for index, value in enumerate(fields) if value.isdigit()), -1)
        if pid_index < 0 or pid_index + 1 >= len(fields):
            continue
        name = fields[-1]
        if "." not in name or name in {"android.system.suspend@1.0-service", "surfaceflinger"}:
            continue
        pid = fields[pid_index]
        processes.setdefault(name, {"name": name, "pid": pid, "label": f"{name} · PID {pid}"})
    return sorted(processes.values(), key=lambda item: item["name"].casefold())


def find_adb_executable() -> str | None:
    bundled = bundled_adb_path()
    if bundled.exists():
        return str(bundled)
    return shutil.which("adb")


class AndroidDeviceService(QObject):
    devicesChanged = Signal()
    refreshingChanged = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._devices: list[AndroidDevice] = []
        self._process: BackgroundProcess | None = None
        self._stdout = bytearray()
        self._stderr = bytearray()
        self._refresh_token = 0

    @property
    def devices(self) -> list[AndroidDevice]:
        return list(self._devices)

    @property
    def refreshing(self) -> bool:
        return self._process is not None

    def refresh(self) -> None:
        if self._process is not None:
            return
        adb = find_adb_executable()
        if not adb:
            self._set_devices([])
            self.errorOccurred.emit("未找到 ADB 运行环境")
            return

        process = BackgroundProcess(self)
        process.stdoutReady.connect(self._stdout.extend)
        process.stderrReady.connect(self._stderr.extend)
        process.finished.connect(self._on_finished)
        process.errorOccurred.connect(self.errorOccurred)
        self._process = process
        self._stdout.clear()
        self._stderr.clear()
        self._refresh_token += 1
        token = self._refresh_token
        self.refreshingChanged.emit()
        if not process.start(adb, ["devices", "-l"]):
            self._process = None
            self.refreshingChanged.emit()
            self._set_devices([])
            process.deleteLater()
            return
        QTimer.singleShot(5000, lambda: self._stop_if_stale(token))

    def _on_finished(self, _exit_code: int) -> None:
        process = self._process
        if process is None:
            return
        output = self._stdout.decode("utf-8", "replace")
        error = self._stderr.decode("utf-8", "replace").strip()
        self._process = None
        self.refreshingChanged.emit()
        self._set_devices(parse_adb_devices(output))
        if error:
            self.errorOccurred.emit(error)
        process.deleteLater()

    def _stop_if_stale(self, token: int) -> None:
        if token != self._refresh_token or self._process is None:
            return
        self._process.kill()
        self.errorOccurred.emit("刷新 Android 设备超时")

    def _set_devices(self, devices: list[AndroidDevice]) -> None:
        if devices == self._devices:
            return
        self._devices = devices
        self.devicesChanged.emit()


class AndroidProcessService(QObject):
    """Load Android processes asynchronously without blocking the Qt UI thread."""

    processesChanged = Signal()
    refreshingChanged = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._processes: list[dict[str, str]] = []
        self._process: BackgroundProcess | None = None
        self._stdout = bytearray()
        self._stderr = bytearray()
        self._serial = ""
        self._pending_serial: str | None = None
        self._refresh_token = 0

    @property
    def processes(self) -> list[dict[str, str]]:
        return list(self._processes)

    @property
    def refreshing(self) -> bool:
        return self._process is not None

    def refresh(self, serial: str) -> None:
        serial = serial.strip()
        if self._process is not None:
            if serial != self._serial:
                self._pending_serial = serial
                self._process.kill()
            return
        if not serial:
            self._set_processes([])
            return
        self._start(serial)

    def _start(self, serial: str) -> None:
        adb = find_adb_executable()
        if not adb:
            self._set_processes([])
            self.errorOccurred.emit("未找到 ADB 运行环境")
            return
        process = BackgroundProcess(self)
        process.stdoutReady.connect(self._stdout.extend)
        process.stderrReady.connect(self._stderr.extend)
        process.finished.connect(self._on_finished)
        process.errorOccurred.connect(self.errorOccurred)
        self._process = process
        self._serial = serial
        self._stdout.clear()
        self._stderr.clear()
        self._refresh_token += 1
        token = self._refresh_token
        self.refreshingChanged.emit()
        process.start(adb, ["-s", serial, "shell", "ps", "-A"])
        QTimer.singleShot(5000, lambda: self._stop_if_stale(token))

    def _on_finished(self, exit_code: int) -> None:
        process = self._process
        if process is None:
            return
        output = self._stdout.decode("utf-8", "replace")
        error = self._stderr.decode("utf-8", "replace").strip()
        self._process = None
        self._serial = ""
        self.refreshingChanged.emit()
        self._set_processes(parse_android_processes(output) if exit_code == 0 else [])
        if error:
            self.errorOccurred.emit(error)
        process.deleteLater()
        pending = self._pending_serial
        self._pending_serial = None
        if pending is not None:
            self.refresh(pending)

    def _stop_if_stale(self, token: int) -> None:
        if token != self._refresh_token or self._process is None:
            return
        self._process.kill()
        self.errorOccurred.emit("刷新 Android 进程超时")

    def _set_processes(self, processes: list[dict[str, str]]) -> None:
        if processes == self._processes:
            return
        self._processes = processes
        self.processesChanged.emit()

