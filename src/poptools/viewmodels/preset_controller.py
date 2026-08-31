from __future__ import annotations

import os
import shutil
import uuid
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import (
    Property,
    QObject,
    QProcess,
    QProcessEnvironment,
    QTimer,
    QUrl,
    Signal,
    Slot,
)
from PySide6.QtWidgets import QFileDialog

from poptools.infrastructure.android_device_service import find_adb_executable
from poptools.infrastructure.scrcpy_controller import (
    _close_window,
    _find_process_window,
    _hide_window_from_taskbar,
)
from poptools.infrastructure.screen_color_picker import ScreenColorPickerOverlay
from poptools.paths import (
    AppPaths,
    bundled_adb_path,
    bundled_android_tools_dir,
    bundled_scrcpy_path,
)


class PresetController(QObject):
    """Local preset operations and Android recording workflow."""

    recordingChanged = Signal()
    recordingError = Signal(str)
    recordingSaved = Signal(str)
    screenColorPicked = Signal(str)
    screenColorPickingCancelled = Signal()

    def __init__(self, paths: AppPaths | None = None, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.paths = paths
        self._recording = False
        self._recording_serial = ""
        self._recording_dir: Path | None = None
        self._video_process: QProcess | None = None
        self._log_process: QProcess | None = None
        self._stop_processes: list[QProcess] = []
        self._log_pull_process: QProcess | None = None
        self._remote_log = ""
        self._recording_window_title = ""
        self._recording_window_handle = 0
        self._recording_window_attempts = 0
        self._recording_errors = bytearray()
        self._save_parent: Path | None = None
        self._discard_requested = False
        self._video_finished = False
        self._log_finished = False
        self._log_pull_succeeded = False
        self._log_pull_attempts = 0
        self._screen_color_picker: ScreenColorPickerOverlay | None = None
        self._screen_color_source: QObject | None = None
        self._screen_color_picking = False

    @Property(bool, notify=recordingChanged)
    def recording(self) -> bool:
        return self._recording

    @Slot(QObject, result=bool)
    def startScreenColorPicking(self, source_window: QObject | None) -> bool:
        if self._screen_color_picking:
            return False
        self._screen_color_picking = True
        self._screen_color_source = source_window
        if source_window is not None:
            source_window.setProperty("visible", False)
        # Let the compositor remove the source window before taking screenshots.
        QTimer.singleShot(160, self._begin_screen_color_picking)
        return True

    def _begin_screen_color_picking(self) -> None:
        if not self._screen_color_picking:
            return
        picker = ScreenColorPickerOverlay(
            self._on_screen_color_picked,
            self._on_screen_color_picking_cancelled,
        )
        self._screen_color_picker = picker
        picker.begin()

    def _on_screen_color_picked(self, color: str) -> None:
        self._screen_color_picker = None
        self._screen_color_picking = False
        self._restore_screen_color_source()
        self.screenColorPicked.emit(color)

    def _on_screen_color_picking_cancelled(self) -> None:
        self._screen_color_picker = None
        self._screen_color_picking = False
        self._restore_screen_color_source()
        self.screenColorPickingCancelled.emit()

    def _restore_screen_color_source(self) -> None:
        source = self._screen_color_source
        self._screen_color_source = None
        if source is None:
            return
        try:
            source.setProperty("visible", True)
            if hasattr(source, "raise_"):
                source.raise_()
            if hasattr(source, "requestActivate"):
                source.requestActivate()
            elif hasattr(source, "activateWindow"):
                source.activateWindow()
        except RuntimeError:
            # The originating QML window may have been destroyed while picking.
            pass

    @Slot(str, result=bool)
    def startRecording(self, serial: str) -> bool:
        if self._recording:
            return False
        adb = find_adb_executable()
        scrcpy = bundled_scrcpy_path()
        server = bundled_android_tools_dir() / "scrcpy-server"
        serial = serial.strip()
        missing = [
            path.name
            for path in (bundled_adb_path(), scrcpy, server)
            if not path.is_file()
        ]
        if not adb or missing:
            detail = f"：{', '.join(missing)}" if missing else ""
            self.recordingError.emit(f"内置录屏组件不完整{detail}")
            return False
        if not serial:
            self.recordingError.emit("请先连接并选择 Android 设备")
            return False
        base = self.paths.outputs_dir if self.paths else Path.cwd() / "outputs"
        work_dir = base / f".recording-{uuid.uuid4().hex}"
        try:
            work_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            self.recordingError.emit(f"无法创建录制临时目录：{exc}")
            return False
        self._recording_serial = serial
        self._recording_dir = work_dir
        self._discard_requested = False
        self._video_finished = False
        self._log_finished = False
        self._log_pull_succeeded = False
        self._log_pull_attempts = 0
        self._recording_errors.clear()
        self._recording_window_title = f"PopTools-recording-{uuid.uuid4().hex}"
        self._recording_window_handle = 0
        self._recording_window_attempts = 0
        self._remote_log = f"/sdcard/poptools-{uuid.uuid4().hex}.log"
        video = QProcess(self)
        video.setProgram(str(scrcpy))
        video.setWorkingDirectory(str(scrcpy.parent))
        environment = QProcessEnvironment.systemEnvironment()
        environment.insert("ADB", str(bundled_adb_path()))
        environment.insert("SCRCPY_SERVER_PATH", str(server))
        environment.insert(
            "PATH",
            f"{scrcpy.parent}{os.pathsep}{environment.value('PATH')}",
        )
        video.setProcessEnvironment(environment)
        video.setArguments(
            [
                "--serial",
                serial,
                "--record",
                str(work_dir / "recording.mp4"),
                "--audio-source=voice-performance",
                "--audio-codec=aac",
                "--require-audio",
                "--no-audio-playback",
                "--no-control",
                "--window-title",
                self._recording_window_title,
                "--window-x=-32000",
                "--window-y=-32000",
                "--window-width=1",
                "--window-height=1",
            ]
        )
        video.readyReadStandardError.connect(self._read_recording_error)
        video.finished.connect(self._on_video_finished)
        video.errorOccurred.connect(self._on_video_process_error)
        log = QProcess(self)
        log.setProgram(adb)
        log.setArguments([
            "-s", serial, "shell", "logcat", "-v", "threadtime", "-f", self._remote_log
        ])
        log.finished.connect(lambda _code, _status: self._on_log_finished())
        self._video_process = video
        self._log_process = log
        self._recording = True
        self.recordingChanged.emit()
        video.start()
        log.start()
        QTimer.singleShot(0, self._hide_recording_window)
        return True

    @Slot()
    def stopRecording(self) -> None:
        if not self._recording:
            return
        adb = find_adb_executable()
        if adb:
            self._signal_remote_process(adb, "logcat")

        handle = self._recording_window_handle or self._find_recording_window()
        if handle:
            _close_window(handle)
        elif self._video_process is not None:
            self._video_process.terminate()
        if self._log_process is not None:
            self._log_process.terminate()
        QTimer.singleShot(8000, self._kill_recording_processes)

    def _find_recording_window(self) -> int:
        process = self._video_process
        if process is None or process.state() == QProcess.ProcessState.NotRunning:
            return 0
        return _find_process_window(int(process.processId()), self._recording_window_title)

    def _hide_recording_window(self) -> None:
        if not self._recording or self._recording_window_handle:
            return
        self._recording_window_attempts += 1
        handle = self._find_recording_window()
        if handle:
            _hide_window_from_taskbar(handle)
            self._recording_window_handle = handle
            return
        if self._recording_window_attempts < 300:
            QTimer.singleShot(10, self._hide_recording_window)

    def _signal_remote_process(self, adb: str, process_name: str) -> None:
        stop_process = QProcess(self)
        stop_process.setProgram(adb)
        stop_process.setArguments([
            "-s", self._recording_serial, "shell", "pkill", "-INT", process_name
        ])
        stop_process.finished.connect(stop_process.deleteLater)
        self._stop_processes.append(stop_process)
        stop_process.finished.connect(lambda: self._stop_processes.remove(stop_process))
        stop_process.start()

    def _kill_recording_processes(self) -> None:
        for process in (self._video_process, self._log_process):
            if process is not None and process.state() != QProcess.ProcessState.NotRunning:
                process.kill()

    def _read_recording_error(self) -> None:
        if self._video_process is not None:
            self._recording_errors.extend(self._video_process.readAllStandardError().data())

    def _on_video_process_error(self, _error: QProcess.ProcessError) -> None:
        if self._recording:
            self.recordingError.emit("录屏组件启动失败")

    def _on_video_finished(
        self,
        exit_code: int,
        _status: QProcess.ExitStatus,
    ) -> None:
        self._read_recording_error()
        output = bytes(self._recording_errors).decode("utf-8", "replace").strip()
        recording_file = (
            self._recording_dir / "recording.mp4"
            if self._recording_dir is not None
            else None
        )
        if exit_code != 0 or recording_file is None or not recording_file.is_file():
            detail = output.splitlines()[-1] if output else f"退出代码 {exit_code}"
            self.recordingError.emit(
                "音视频录制失败：设备可能不支持同时采集系统声音和麦克风。"
                f"\n{detail}"
            )
            if self._log_process is not None:
                self._log_process.terminate()
            adb = find_adb_executable()
            if adb:
                self._signal_remote_process(adb, "logcat")
        self._video_finished = True
        self._maybe_prepare_save()

    def _on_log_finished(self) -> None:
        QTimer.singleShot(500, self._complete_log_finish)

    def _complete_log_finish(self) -> None:
        self._log_finished = True
        self._start_log_pull()
        self._maybe_prepare_save()

    def _start_log_pull(self) -> None:
        if self._recording_dir is None or self._log_pull_process is not None:
            return
        adb = find_adb_executable()
        if not adb:
            self.recordingError.emit("未找到 ADB 运行环境")
            return
        pull = QProcess(self)
        self._log_pull_attempts += 1
        pull.setProgram(adb)
        pull.setArguments([
            "-s", self._recording_serial, "pull", self._remote_log,
            str(self._recording_dir / "logcat.txt"),
        ])
        pull.finished.connect(lambda _code, _status: self._on_log_pull_finished(pull.exitCode()))
        self._log_pull_process = pull
        pull.start()

    def _on_log_pull_finished(self, exit_code: int) -> None:
        if exit_code != 0:
            if self._log_pull_attempts < 3:
                QTimer.singleShot(1000, self._start_log_pull)
            else:
                self.recordingError.emit("日志文件拉取失败，请确认设备仍保持连接")
        else:
            self._log_pull_succeeded = True
        if self._log_pull_process is not None:
            self._log_pull_process.deleteLater()
            self._log_pull_process = None
        if exit_code == 0 or self._log_pull_attempts >= 3:
            self._maybe_prepare_save()

    def _delete_remote_file(self, remote_path: str) -> None:
        adb = find_adb_executable()
        if not adb:
            return
        cleanup = QProcess(self)
        cleanup.start(adb, ["-s", self._recording_serial, "shell", "rm", "-f", remote_path])
        cleanup.finished.connect(cleanup.deleteLater)

    def _maybe_prepare_save(self) -> None:
        if not (
            self._video_finished
            and self._log_finished
            and self._log_pull_process is None
        ):
            return
        self._recording = False
        self.recordingChanged.emit()
        if self._save_parent is not None:
            self._finish_save(self._save_parent)
            self._save_parent = None
        elif self._discard_requested:
            self._discard_recording()

    @Slot(str)
    def saveRecording(self, parent_path: str) -> None:
        raw_path = parent_path.strip()
        if raw_path.startswith("file:"):
            raw_path = QUrl(raw_path).toLocalFile()
        if not raw_path:
            self.recordingError.emit("未选择录制文件保存目录")
            return
        parent = Path(raw_path)
        if (
            not self._video_finished
            or not self._log_finished
            or self._log_pull_process is not None
        ):
            self._save_parent = parent
            return
        self._finish_save(parent)

    @Slot(result=bool)
    def chooseRecordingDirectory(self) -> bool:
        downloads = Path.home() / "Downloads"
        source = QFileDialog.getExistingDirectory(
            None,
            "选择录制文件保存位置",
            str(downloads if downloads.is_dir() else Path.home()),
            QFileDialog.Option.ShowDirsOnly,
        )
        if not source:
            self._discard_requested = True
            if not self._recording and self._recording_dir is not None:
                self._discard_recording()
            return False
        self.saveRecording(source)
        return True

    def _finish_save(self, parent: Path) -> None:
        if self._recording_dir is None:
            return
        folder = parent / datetime.now().strftime("%Y-%m-%d-%H-%M")
        try:
            folder.mkdir(parents=True, exist_ok=True)
            copied = 0
            for source in (
                self._recording_dir / "logcat.txt",
                self._recording_dir / "recording.mp4",
            ):
                if source.exists():
                    shutil.copy2(source, folder / source.name)
                    copied += 1
            if copied == 0:
                raise OSError("没有可保存的录制文件")
            if self._log_pull_succeeded and (folder / "logcat.txt").exists():
                self._delete_remote_file(self._remote_log)
            self.recordingSaved.emit(str(folder))
            shutil.rmtree(self._recording_dir, ignore_errors=True)
        except OSError as exc:
            self.recordingError.emit(f"录制文件保存失败：{exc}")
        finally:
            self._recording_dir = None

    def _discard_recording(self) -> None:
        """Remove recording files when the user does not save them."""
        if self._recording_dir is not None:
            shutil.rmtree(self._recording_dir, ignore_errors=True)
            self._recording_dir = None
        if self._remote_log:
            self._delete_remote_file(self._remote_log)

