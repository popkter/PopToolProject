from __future__ import annotations

import ctypes
import os
import uuid
from typing import Any

from PySide6.QtCore import QObject, QRect, QTimer, Signal
from PySide6.QtGui import QWindow

from poptools.infrastructure.background_process import BackgroundProcess
from poptools.paths import bundled_adb_path, bundled_android_tools_dir, bundled_scrcpy_path


class ScrcpyController(QObject):
    """Run the bundled scrcpy client and host its native window inside PopTools."""

    output = Signal(str)
    started = Signal()
    runningChanged = Signal(bool)
    finished = Signal(int)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._process: BackgroundProcess | None = None
        self._started = False
        self._host_window: QWindow | None = None
        self._scrcpy_window = 0
        self._host_rect = QRect()
        self._host_visible = False
        self._window_title = ""
        self._embed_attempts = 0
        self._embed_timer = QTimer(self)
        self._embed_timer.setInterval(50)
        self._embed_timer.timeout.connect(self._try_embed_window)

    @property
    def running(self) -> bool:
        return self._started

    @property
    def active(self) -> bool:
        return self._process is not None

    def attach_window(self, window: QWindow) -> None:
        self._host_window = window

    def start(self, serial: str) -> bool:
        if self.active:
            return False
        if os.name != "nt":
            self.output.emit("应用内投屏当前仅支持 Windows。\n")
            return False
        scrcpy = bundled_scrcpy_path()
        adb = bundled_adb_path()
        server = bundled_android_tools_dir() / "scrcpy-server"
        missing = [path.name for path in (scrcpy, adb, server) if not path.is_file()]
        if missing:
            self.output.emit(f"内置投屏组件不完整：{', '.join(missing)}\n")
            return False
        if not serial:
            self.output.emit("请先选择已连接的 Android 设备。\n")
            return False
        if self._host_window is None:
            self.output.emit("投屏区域尚未准备好，请稍后重试。\n")
            return False

        self._window_title = f"PopTools-scrcpy-{uuid.uuid4().hex}"
        process = BackgroundProcess(self)
        process.stdoutReady.connect(self._read_output)
        process.stderrReady.connect(self._read_error)
        process.started.connect(self._on_started)
        process.errorOccurred.connect(self._on_error)
        process.finished.connect(self._on_finished)
        self._process = process
        self._started = False
        self._scrcpy_window = 0
        self._embed_attempts = 0
        environment = dict(os.environ)
        environment["ADB"] = str(adb)
        environment["SCRCPY_SERVER_PATH"] = str(server)
        environment["PATH"] = f"{scrcpy.parent}{os.pathsep}{environment.get('PATH', '')}"
        accepted = process.start(
            str(scrcpy),
            [
                "--serial",
                serial,
                "--window-title",
                self._window_title,
                "--window-borderless",
                "--no-window-aspect-ratio-lock",
                "--no-audio",
            ],
            cwd=scrcpy.parent,
            environment=environment,
        )
        if not accepted:
            self._process = None
            process.deleteLater()
            return False
        self.output.emit(f"正在连接设备 {serial} 并启动应用内投屏…\n")
        return True

    def stop(self) -> None:
        process = self._process
        if process is None:
            return
        self._embed_timer.stop()
        if self._scrcpy_window:
            _show_window(self._scrcpy_window, False)
            _close_window(self._scrcpy_window)
        else:
            process.terminate()
        QTimer.singleShot(500, self._terminate_if_running)
        QTimer.singleShot(2500, self._kill_if_running)

    def set_geometry(self, rect: QRect, visible: bool) -> None:
        self._host_rect = QRect(rect)
        self._host_visible = visible
        self._sync_embedded_window()

    def _try_embed_window(self) -> None:
        process = self._process
        if process is None:
            self._embed_timer.stop()
            return
        self._embed_attempts += 1
        handle = _find_process_window(process.process_id, self._window_title)
        if handle:
            self._embed_timer.stop()
            self._scrcpy_window = handle
            if self._host_window is None or not _embed_window(
                handle, int(self._host_window.winId())
            ):
                self.output.emit("无法将 scrcpy 窗口嵌入应用。\n")
                self.stop()
                return
            self._sync_embedded_window()
            self.output.emit("投屏已连接。\n")
        elif self._embed_attempts >= 200:
            self._embed_timer.stop()
            self.output.emit("等待 scrcpy 投屏窗口超时。\n")
            self.stop()

    def _sync_embedded_window(self) -> None:
        if not self._scrcpy_window or self._host_window is None:
            return
        scale = self._host_window.devicePixelRatio()
        rect = QRect(
            round(self._host_rect.x() * scale),
            round(self._host_rect.y() * scale),
            round(self._host_rect.width() * scale),
            round(self._host_rect.height() * scale),
        )
        _move_window(self._scrcpy_window, rect, self._host_visible and not rect.isEmpty())

    def _on_started(self) -> None:
        self._started = True
        self._embed_timer.start()
        self.started.emit()
        self.runningChanged.emit(True)

    def _read_output(self, payload: bytes) -> None:
        self.output.emit(payload.decode("utf-8", "replace"))

    def _read_error(self, payload: bytes) -> None:
        self.output.emit(payload.decode("utf-8", "replace"))

    def _on_error(self, message: str) -> None:
        self.output.emit(f"投屏启动失败：{message}\n")

    def _on_finished(self, exit_code: int) -> None:
        self._finalize(exit_code)

    def _finalize(self, exit_code: int) -> None:
        process = self._process
        if process is None:
            return
        self._embed_timer.stop()
        self._process = None
        was_started = self._started
        self._started = False
        self._scrcpy_window = 0
        process.deleteLater()
        if was_started:
            self.runningChanged.emit(False)
        self.finished.emit(exit_code)

    def _terminate_if_running(self) -> None:
        if self._process is not None:
            self._process.terminate()

    def _kill_if_running(self) -> None:
        if self._process is not None:
            self._process.kill()


def _user32() -> Any:
    return ctypes.WinDLL("user32", use_last_error=True)


def _find_process_window(process_id: int, title: str) -> int:
    if os.name != "nt" or not process_id:
        return 0
    user32 = _user32()
    found = 0
    callback_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    user32.EnumWindows.argtypes = [callback_type, ctypes.c_void_p]
    user32.EnumWindows.restype = ctypes.c_bool
    user32.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]
    user32.GetWindowThreadProcessId.restype = ctypes.c_ulong
    user32.IsWindowVisible.argtypes = [ctypes.c_void_p]
    user32.IsWindowVisible.restype = ctypes.c_bool
    user32.GetWindowTextLengthW.argtypes = [ctypes.c_void_p]
    user32.GetWindowTextLengthW.restype = ctypes.c_int
    user32.GetWindowTextW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_int]
    user32.GetWindowTextW.restype = ctypes.c_int

    def visit(handle: int, _context: int) -> bool:
        nonlocal found
        window_pid = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(window_pid))
        if window_pid.value != process_id or not user32.IsWindowVisible(handle):
            return True
        length = user32.GetWindowTextLengthW(handle)
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(handle, buffer, len(buffer))
        if buffer.value == title:
            found = int(handle)
            return False
        return True

    callback = callback_type(visit)
    user32.EnumWindows(callback, 0)
    return found


def _embed_window(child: int, parent: int) -> bool:
    if os.name != "nt" or not child or not parent:
        return False
    user32 = _user32()
    get_style = user32.GetWindowLongPtrW
    set_style = user32.SetWindowLongPtrW
    get_style.argtypes = [ctypes.c_void_p, ctypes.c_int]
    get_style.restype = ctypes.c_ssize_t
    set_style.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_ssize_t]
    set_style.restype = ctypes.c_ssize_t
    user32.SetParent.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    user32.SetParent.restype = ctypes.c_void_p
    style = int(get_style(child, -16))
    style &= ~(0x80000000 | 0x00C00000 | 0x00040000 | 0x00080000 | 0x00030000)
    style |= 0x40000000
    set_style(child, -16, style)
    ctypes.set_last_error(0)
    previous_parent = user32.SetParent(child, parent)
    return bool(previous_parent) or ctypes.get_last_error() == 0


def _move_window(handle: int, rect: QRect, visible: bool) -> None:
    if os.name != "nt" or not handle:
        return
    user32 = _user32()
    user32.SetWindowPos.argtypes = [
        ctypes.c_void_p,
        ctypes.c_void_p,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_uint,
    ]
    user32.SetWindowPos.restype = ctypes.c_bool

    if not visible:
        _show_window(handle, False)
        return
    user32.SetWindowPos(
        handle,
        0,
        rect.x(),
        rect.y(),
        max(1, rect.width()),
        max(1, rect.height()),
        0x0010 | 0x0020 | 0x0040,
    )


def _show_window(handle: int, visible: bool) -> None:
    if os.name == "nt" and handle:
        user32 = _user32()
        user32.ShowWindow.argtypes = [ctypes.c_void_p, ctypes.c_int]
        user32.ShowWindow(handle, 5 if visible else 0)


def _close_window(handle: int) -> None:
    if os.name != "nt" or not handle:
        return
    user32 = _user32()
    user32.PostMessageW.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_void_p,
        ctypes.c_void_p,
    ]
    user32.PostMessageW.restype = ctypes.c_bool
    user32.PostMessageW(handle, 0x0010, 0, 0)
