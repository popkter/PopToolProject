"""Coordinate managed Python readers and pip writers across app processes.

This is runtime bootstrap code; the C++ application itself does not need Python.
Locks are nonblocking so a Python parent invoking pip cannot deadlock itself.
"""
import atexit
import ctypes
from ctypes import wintypes
import os
import re
import sys
import msvcrt


class _Overlapped(ctypes.Structure):
    _fields_ = [("internal", ctypes.c_size_t), ("internal_high", ctypes.c_size_t),
                ("offset", wintypes.DWORD), ("offset_high", wintypes.DWORD),
                ("event", wintypes.HANDLE)]


_descriptor = None


def pip_writes_environment():
    original = list(getattr(sys, "orig_argv", []))
    arguments = None
    index = 1
    while index < len(original):
        option = original[index]
        if option == "-m":
            if index + 1 < len(original) and original[index + 1] == "pip":
                arguments = original[index + 2:]
            break
        if option in ("-c", "--") or not option.startswith("-"):
            break
        index += 2 if option in ("-W", "-X") else 1
    if arguments is None and sys.argv and re.fullmatch(r"pip[\d.]*(?:\.exe)?", os.path.basename(sys.argv[0]), re.I):
        arguments = sys.argv[1:]
    if arguments is None:
        return False
    # Unknown pip operations conservatively require exclusive access.
    readonly = {"list", "show", "freeze", "check", "debug", "help"}
    writes = {"install", "uninstall", "download", "wheel", "cache", "config"}
    if any(arg in writes for arg in arguments):
        return True
    commands = readonly | writes | {"index", "inspect"}
    command = next((arg for arg in arguments if arg in commands), None)
    if command in readonly:
        return False
    if command is None and any(arg in ("--version", "-V", "--help", "-h") for arg in arguments):
        return False
    return True


def acquire(environment_directory):
    global _descriptor
    if _descriptor is not None:
        return
    version_directory = os.path.dirname(os.path.abspath(environment_directory))
    lock_directory = os.path.join(os.path.dirname(version_directory), ".locks")
    os.makedirs(lock_directory, exist_ok=True)
    lock_path = os.path.join(lock_directory, os.path.basename(version_directory) + ".lock")
    descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    lock = kernel.LockFileEx
    lock.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.DWORD,
                     wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(_Overlapped)]
    lock.restype = wintypes.BOOL
    exclusive = pip_writes_environment()
    if not lock(msvcrt.get_osfhandle(descriptor), 1 | (2 if exclusive else 0), 0, 1, 0, ctypes.byref(_Overlapped())):
        error = ctypes.get_last_error()
        os.close(descriptor)
        raise OSError(error, "Python 环境正在被其他进程使用或修改；请结束相关 Python 任务后重试。")
    _descriptor = descriptor
    atexit.register(os.close, descriptor)


def acquire_or_exit(environment_directory):
    try:
        acquire(environment_directory)
    except Exception as error:
        # sitecustomize exceptions are otherwise ignored by CPython. Fail closed.
        os.write(2, ("UTerminal: " + str(error) + "\n").encode("utf-8", errors="replace"))
        os._exit(75)
