from __future__ import annotations

import ctypes
import os
import select
import signal
import struct
import subprocess
import threading
from collections.abc import Mapping, Sequence
from contextlib import suppress
from pathlib import Path
from typing import Any

import psutil  # type: ignore[import-untyped]
from PySide6.QtCore import QObject, QThread, Signal

if os.name == "nt":
    from winpty import PTY, Backend  # type: ignore[import-untyped]

    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _kernel32.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    _kernel32.OpenProcess.restype = ctypes.c_void_p
    _kernel32.TerminateProcess.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    _kernel32.TerminateProcess.restype = ctypes.c_int
    _kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    _kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p]
    _kernel32.CreateJobObjectW.restype = ctypes.c_void_p
    _kernel32.AssignProcessToJobObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    _kernel32.AssignProcessToJobObject.restype = ctypes.c_int
    _kernel32.TerminateJobObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    _kernel32.TerminateJobObject.restype = ctypes.c_int
    _PROCESS_TERMINATE = 0x0001
    _PROCESS_SET_QUOTA = 0x0100


class ConPtySession(QThread):
    """Native ConPTY I/O without an intermediate socket or reader thread."""

    outputReceived = Signal(bytes)
    processExited = Signal(int)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._pty: Any | None = None
        self._master_fd = -1
        self._process: subprocess.Popen[bytes] | None = None
        self._pid = 0
        self._job: int | None = None
        self._console_hosts: set[int] = set()
        self._write_lock = threading.Lock()

    def start_process(
        self,
        program: Path,
        arguments: Sequence[str],
        working_directory: Path,
        environment: Mapping[str, str],
        columns: int = 120,
        rows: int = 30,
    ) -> None:
        if self.isRunning() or self._pty is not None:
            raise RuntimeError("终端会话已经启动")

        if os.name != "nt":
            self._start_posix_process(
                program, arguments, working_directory, environment, columns, rows
            )
            return

        existing_hosts = self._current_console_hosts()
        pty = PTY(max(1, columns), max(1, rows), backend=Backend.ConPTY)
        environment_block = "\0".join(
            f"{key}={value}" for key, value in environment.items()
        ) + "\0"
        command_line = " " + subprocess.list2cmdline(list(arguments))
        try:
            pty.spawn(
                str(program),
                cmdline=command_line,
                cwd=str(working_directory),
                env=environment_block,
            )
        except Exception:
            with suppress(Exception):
                pty.cancel_io()
            raise
        self._pty = pty
        self._pid = int(pty.pid)
        self._console_hosts = self._current_console_hosts() - existing_hosts
        self._assign_job()
        self.start()

    def run(self) -> None:
        if os.name != "nt":
            self._run_posix()
            return
        pty = self._pty
        if pty is None:
            return
        pending: list[str] = []
        pending_size = 0
        while not self.isInterruptionRequested() and pty.isalive():
            try:
                data = pty.read(blocking=False)
            except Exception:
                if not pty.isalive():
                    break
                self.msleep(16)
                continue
            if data:
                pending.append(data)
                pending_size += len(data)
                while pending_size < 65_536:
                    try:
                        following = pty.read(blocking=False)
                    except Exception:
                        following = ""
                    if not following:
                        break
                    pending.append(following)
                    pending_size += len(following)
                self._emit_pending(pending)
                pending = []
                pending_size = 0
            else:
                self.msleep(16)
        self._emit_pending(pending)
        with suppress(Exception):
            exit_code = int(pty.get_exitstatus() or 0)
            self.processExited.emit(exit_code)

    def write(self, data: bytes) -> bool:
        if os.name != "nt":
            if self._master_fd < 0 or self._process is None or self._process.poll() is not None:
                return False
            with self._write_lock:
                try:
                    os.write(self._master_fd, data)
                except OSError:
                    return False
            return True
        pty = self._pty
        if pty is None or not pty.isalive() or not data:
            return False
        with self._write_lock:
            try:
                pty.write(data.decode("utf-8", errors="replace"))
            except Exception:
                return False
            return True

    def resize(self, columns: int, rows: int) -> None:
        if os.name != "nt":
            if self._master_fd >= 0:
                with suppress(OSError):
                    import fcntl
                    import termios

                    size = struct.pack("HHHH", max(1, rows), max(1, columns), 0, 0)
                    fcntl.ioctl(self._master_fd, termios.TIOCSWINSZ, size)
            return
        pty = self._pty
        if pty is not None and pty.isalive():
            with suppress(Exception):
                pty.set_size(max(1, columns), max(1, rows))

    def stop_process(self) -> None:
        self.requestInterruption()
        if os.name != "nt":
            self._terminate_posix_process(signal.SIGTERM)
            return
        pty = self._pty
        if pty is not None:
            with suppress(Exception):
                pty.cancel_io()
        self._terminate_process()

    def dispose(self) -> None:
        if os.name != "nt":
            self._terminate_posix_process(signal.SIGKILL)
            if self._master_fd >= 0:
                with suppress(OSError):
                    os.close(self._master_fd)
            self._master_fd = -1
            self._process = None
            self._pty = None
            self._pid = 0
            return
        pty = self._pty
        self._pty = None
        self._terminate_process()
        if pty is not None:
            with suppress(Exception):
                pty.cancel_io()
        self._terminate_console_hosts()
        self._close_job()
        self._pid = 0

    def _terminate_process(self) -> None:
        if os.name != "nt" or not self._pid:
            return
        if self._job:
            _kernel32.TerminateJobObject(self._job, 1)
            return
        handle = _kernel32.OpenProcess(_PROCESS_TERMINATE, False, self._pid)
        if handle:
            _kernel32.TerminateProcess(handle, 1)
            _kernel32.CloseHandle(handle)

    def _assign_job(self) -> None:
        if os.name != "nt" or not self._pid:
            return
        job = _kernel32.CreateJobObjectW(None, None)
        if not job:
            return
        process = _kernel32.OpenProcess(
            _PROCESS_TERMINATE | _PROCESS_SET_QUOTA, False, self._pid
        )
        if not process:
            _kernel32.CloseHandle(job)
            return
        assigned = _kernel32.AssignProcessToJobObject(job, process)
        _kernel32.CloseHandle(process)
        if assigned:
            self._job = int(job)
        else:
            _kernel32.CloseHandle(job)

    def _close_job(self) -> None:
        if self._job:
            _kernel32.CloseHandle(self._job)
            self._job = None

    def _current_console_hosts(self) -> set[int]:
        with suppress(psutil.Error):
            return {
                process.pid
                for process in psutil.Process().children(recursive=False)
                if process.name().casefold() == "openconsole.exe"
            }
        return set()

    def _terminate_console_hosts(self) -> None:
        hosts = self._console_hosts
        self._console_hosts = set()
        for pid in hosts:
            with suppress(psutil.Error):
                process = psutil.Process(pid)
                if process.name().casefold() == "openconsole.exe":
                    process.terminate()
                    process.wait(timeout=1.0)

    def _emit_pending(self, chunks: list[str]) -> None:
        if chunks:
            self.outputReceived.emit("".join(chunks).encode("utf-8", errors="replace"))

    def _start_posix_process(
        self,
        program: Path,
        arguments: Sequence[str],
        working_directory: Path,
        environment: Mapping[str, str],
        columns: int,
        rows: int,
    ) -> None:
        import pty

        master_fd, slave_fd = pty.openpty()
        self._master_fd = master_fd
        self.resize(columns, rows)
        try:
            process = subprocess.Popen(
                [str(program), *arguments],
                cwd=str(working_directory),
                env=dict(environment),
                stdin=slave_fd,
                stdout=slave_fd,
                stderr=slave_fd,
                start_new_session=True,
                close_fds=True,
            )
        except Exception:
            os.close(master_fd)
            self._master_fd = -1
            raise
        finally:
            os.close(slave_fd)
        self._process = process
        self._pid = process.pid
        self._pty = process
        self.start()

    def _run_posix(self) -> None:
        process = self._process
        master_fd = self._master_fd
        if process is None or master_fd < 0:
            return
        while not self.isInterruptionRequested():
            ready, _, _ = select.select([master_fd], [], [], 0.05)
            if ready:
                try:
                    data = os.read(master_fd, 65_536)
                except OSError:
                    data = b""
                if data:
                    self.outputReceived.emit(data)
                elif process.poll() is not None:
                    break
            elif process.poll() is not None:
                break
        with suppress(subprocess.TimeoutExpired):
            process.wait(timeout=0.5)
        self.processExited.emit(int(process.returncode or 0))

    def _terminate_posix_process(self, sig: signal.Signals) -> None:
        process = self._process
        if process is None or process.poll() is not None:
            return
        with suppress(OSError):
            os.killpg(process.pid, sig)
