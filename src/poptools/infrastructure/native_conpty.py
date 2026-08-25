from __future__ import annotations

import ctypes
import os
import subprocess
import time
from collections.abc import Mapping, Sequence
from pathlib import Path

if os.name != "nt":
    raise ImportError("native_conpty is only available on Windows")


_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_HANDLE = ctypes.c_void_p
_DWORD = ctypes.c_uint32
_SIZE_T = ctypes.c_size_t
_BOOL = ctypes.c_int

_EXTENDED_STARTUPINFO_PRESENT = 0x00080000
_CREATE_UNICODE_ENVIRONMENT = 0x00000400
_STARTF_USESTDHANDLES = 0x00000100
_PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = 0x00020016
_STILL_ACTIVE = 259


class _Coord(ctypes.Structure):
    _fields_ = [("X", ctypes.c_short), ("Y", ctypes.c_short)]


class _StartupInfoW(ctypes.Structure):
    _fields_ = [
        ("cb", _DWORD),
        ("lpReserved", ctypes.c_wchar_p),
        ("lpDesktop", ctypes.c_wchar_p),
        ("lpTitle", ctypes.c_wchar_p),
        ("dwX", _DWORD),
        ("dwY", _DWORD),
        ("dwXSize", _DWORD),
        ("dwYSize", _DWORD),
        ("dwXCountChars", _DWORD),
        ("dwYCountChars", _DWORD),
        ("dwFillAttribute", _DWORD),
        ("dwFlags", _DWORD),
        ("wShowWindow", ctypes.c_ushort),
        ("cbReserved2", ctypes.c_ushort),
        ("lpReserved2", ctypes.POINTER(ctypes.c_ubyte)),
        ("hStdInput", _HANDLE),
        ("hStdOutput", _HANDLE),
        ("hStdError", _HANDLE),
    ]


class _StartupInfoExW(ctypes.Structure):
    _fields_ = [
        ("StartupInfo", _StartupInfoW),
        ("lpAttributeList", ctypes.c_void_p),
    ]


class _ProcessInformation(ctypes.Structure):
    _fields_ = [
        ("hProcess", _HANDLE),
        ("hThread", _HANDLE),
        ("dwProcessId", _DWORD),
        ("dwThreadId", _DWORD),
    ]


_kernel32.CreatePipe.argtypes = [
    ctypes.POINTER(_HANDLE),
    ctypes.POINTER(_HANDLE),
    ctypes.c_void_p,
    _DWORD,
]
_kernel32.CreatePipe.restype = _BOOL
_kernel32.CreatePseudoConsole.argtypes = [
    _Coord,
    _HANDLE,
    _HANDLE,
    _DWORD,
    ctypes.POINTER(_HANDLE),
]
_kernel32.CreatePseudoConsole.restype = ctypes.c_long
_kernel32.ResizePseudoConsole.argtypes = [_HANDLE, _Coord]
_kernel32.ResizePseudoConsole.restype = ctypes.c_long
_kernel32.ClosePseudoConsole.argtypes = [_HANDLE]
_kernel32.InitializeProcThreadAttributeList.argtypes = [
    ctypes.c_void_p,
    _DWORD,
    _DWORD,
    ctypes.POINTER(_SIZE_T),
]
_kernel32.InitializeProcThreadAttributeList.restype = _BOOL
_kernel32.UpdateProcThreadAttribute.argtypes = [
    ctypes.c_void_p,
    _DWORD,
    _SIZE_T,
    ctypes.c_void_p,
    _SIZE_T,
    ctypes.c_void_p,
    ctypes.c_void_p,
]
_kernel32.UpdateProcThreadAttribute.restype = _BOOL
_kernel32.DeleteProcThreadAttributeList.argtypes = [ctypes.c_void_p]
_kernel32.CreateProcessW.argtypes = [
    ctypes.c_wchar_p,
    ctypes.c_wchar_p,
    ctypes.c_void_p,
    ctypes.c_void_p,
    _BOOL,
    _DWORD,
    ctypes.c_void_p,
    ctypes.c_wchar_p,
    ctypes.POINTER(_StartupInfoW),
    ctypes.POINTER(_ProcessInformation),
]
_kernel32.CreateProcessW.restype = _BOOL
_kernel32.PeekNamedPipe.argtypes = [
    _HANDLE,
    ctypes.c_void_p,
    _DWORD,
    ctypes.c_void_p,
    ctypes.POINTER(_DWORD),
    ctypes.c_void_p,
]
_kernel32.PeekNamedPipe.restype = _BOOL
_kernel32.ReadFile.argtypes = [
    _HANDLE,
    ctypes.c_void_p,
    _DWORD,
    ctypes.POINTER(_DWORD),
    ctypes.c_void_p,
]
_kernel32.ReadFile.restype = _BOOL
_kernel32.WriteFile.argtypes = [
    _HANDLE,
    ctypes.c_void_p,
    _DWORD,
    ctypes.POINTER(_DWORD),
    ctypes.c_void_p,
]
_kernel32.WriteFile.restype = _BOOL
_kernel32.GetExitCodeProcess.argtypes = [_HANDLE, ctypes.POINTER(_DWORD)]
_kernel32.GetExitCodeProcess.restype = _BOOL
_kernel32.CancelIoEx.argtypes = [_HANDLE, ctypes.c_void_p]
_kernel32.CancelIoEx.restype = _BOOL
_kernel32.CloseHandle.argtypes = [_HANDLE]
_kernel32.CloseHandle.restype = _BOOL


def _raise_last_error(action: str) -> None:
    error = ctypes.get_last_error()
    raise OSError(error, f"{action}失败", None, error)


class NativeConPty:
    """Minimal system-ConPTY wrapper that never creates a console window."""

    def __init__(self, columns: int, rows: int) -> None:
        self._input_write = _HANDLE()
        self._output_read = _HANDLE()
        self._pseudo_console = _HANDLE()
        self._process = _HANDLE()
        self._pid = 0
        self._closed = False

        pseudo_input = _HANDLE()
        pseudo_output = _HANDLE()
        try:
            if not _kernel32.CreatePipe(
                ctypes.byref(pseudo_input), ctypes.byref(self._input_write), None, 0
            ):
                _raise_last_error("创建 ConPTY 输入管道")
            if not _kernel32.CreatePipe(
                ctypes.byref(self._output_read), ctypes.byref(pseudo_output), None, 0
            ):
                _raise_last_error("创建 ConPTY 输出管道")
            result = _kernel32.CreatePseudoConsole(
                _Coord(max(1, columns), max(1, rows)),
                pseudo_input,
                pseudo_output,
                0,
                ctypes.byref(self._pseudo_console),
            )
            if result < 0:
                raise OSError(result, "创建 Windows 系统 ConPTY 失败")
        except Exception:
            self.close()
            raise
        finally:
            if pseudo_input:
                _kernel32.CloseHandle(pseudo_input)
            if pseudo_output:
                _kernel32.CloseHandle(pseudo_output)

    @property
    def pid(self) -> int:
        return self._pid

    def spawn(
        self,
        program: Path,
        arguments: Sequence[str],
        working_directory: Path,
        environment: Mapping[str, str],
    ) -> None:
        attribute_size = _SIZE_T()
        _kernel32.InitializeProcThreadAttributeList(None, 1, 0, ctypes.byref(attribute_size))
        attribute_buffer = ctypes.create_string_buffer(attribute_size.value)
        attribute_list = ctypes.cast(attribute_buffer, ctypes.c_void_p)
        if not _kernel32.InitializeProcThreadAttributeList(
            attribute_list, 1, 0, ctypes.byref(attribute_size)
        ):
            _raise_last_error("初始化 ConPTY 进程属性")
        try:
            if not _kernel32.UpdateProcThreadAttribute(
                attribute_list,
                0,
                _PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                self._pseudo_console,
                ctypes.sizeof(_HANDLE),
                None,
                None,
            ):
                _raise_last_error("设置 ConPTY 进程属性")

            startup = _StartupInfoExW()
            startup.StartupInfo.cb = ctypes.sizeof(_StartupInfoExW)
            # Do not inherit redirected handles from the GUI/parent process;
            # the child must use the pseudo console for all terminal I/O.
            startup.StartupInfo.dwFlags |= _STARTF_USESTDHANDLES
            startup.lpAttributeList = attribute_list
            process_info = _ProcessInformation()
            command_line = ctypes.create_unicode_buffer(
                subprocess.list2cmdline([str(program), *arguments])
            )
            environment_block = ctypes.create_unicode_buffer(
                "\0".join(f"{key}={value}" for key, value in environment.items()) + "\0\0"
            )
            creation_flags = _EXTENDED_STARTUPINFO_PRESENT | _CREATE_UNICODE_ENVIRONMENT
            created = _kernel32.CreateProcessW(
                str(program),
                command_line,
                None,
                None,
                False,
                creation_flags,
                environment_block,
                str(working_directory),
                ctypes.byref(startup.StartupInfo),
                ctypes.byref(process_info),
            )
            if not created:
                _raise_last_error("启动 ConPTY 子进程")
            self._process = process_info.hProcess
            self._pid = int(process_info.dwProcessId)
            _kernel32.CloseHandle(process_info.hThread)
        finally:
            _kernel32.DeleteProcThreadAttributeList(attribute_list)

    def read(self, *, blocking: bool = False) -> bytes:
        while not self._closed:
            available = _DWORD()
            if not _kernel32.PeekNamedPipe(
                self._output_read, None, 0, None, ctypes.byref(available), None
            ):
                return b""
            if available.value:
                size = min(available.value, 65_536)
                buffer = ctypes.create_string_buffer(size)
                read = _DWORD()
                if not _kernel32.ReadFile(
                    self._output_read, buffer, size, ctypes.byref(read), None
                ):
                    return b""
                return buffer.raw[: read.value]
            if not blocking or not self.isalive():
                return b""
            time.sleep(0.005)
        return b""

    def write(self, payload: bytes) -> int:
        if self._closed or not payload:
            return 0
        written = _DWORD()
        buffer = ctypes.create_string_buffer(payload)
        if not _kernel32.WriteFile(
            self._input_write,
            buffer,
            len(payload),
            ctypes.byref(written),
            None,
        ):
            return 0
        return int(written.value)

    def set_size(self, columns: int, rows: int) -> None:
        if not self._closed:
            _kernel32.ResizePseudoConsole(
                self._pseudo_console, _Coord(max(1, columns), max(1, rows))
            )

    def isalive(self) -> bool:
        if self._closed or not self._process:
            return False
        exit_code = _DWORD()
        return bool(
            _kernel32.GetExitCodeProcess(self._process, ctypes.byref(exit_code))
            and exit_code.value == _STILL_ACTIVE
        )

    def get_exitstatus(self) -> int | None:
        if not self._process:
            return None
        exit_code = _DWORD()
        if (
            not _kernel32.GetExitCodeProcess(self._process, ctypes.byref(exit_code))
            or exit_code.value == _STILL_ACTIVE
        ):
            return None
        return int(exit_code.value)

    def cancel_io(self) -> None:
        for handle in (self._output_read, self._input_write):
            if handle:
                _kernel32.CancelIoEx(handle, None)

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        self.cancel_io()
        if self._pseudo_console:
            _kernel32.ClosePseudoConsole(self._pseudo_console)
            self._pseudo_console = _HANDLE()
        for name in ("_input_write", "_output_read", "_process"):
            handle = getattr(self, name)
            if handle:
                _kernel32.CloseHandle(handle)
                setattr(self, name, _HANDLE())
        self._pid = 0

    def __del__(self) -> None:
        self.close()
