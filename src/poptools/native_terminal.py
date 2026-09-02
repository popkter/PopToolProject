from __future__ import annotations

import ctypes
import os
import sys
from contextlib import ExitStack, suppress
from pathlib import Path

import PySide6

from poptools.paths import package_root

_library: ctypes.CDLL | None = None


def terminal_library_name() -> str:
    if sys.platform == "win32":
        return "poptools_terminal.dll"
    if sys.platform == "darwin":
        return "libpoptools_terminal.dylib"
    return "libpoptools_terminal.so"


def terminal_library_path() -> Path:
    return package_root() / "native" / terminal_library_name()


def register_terminal_type() -> None:
    """Load the native Qt Quick terminal and register PopTools.Terminal 1.0."""
    global _library
    if _library is not None:
        return
    library_path = terminal_library_path()
    if sys.platform == "win32":
        # A loaded DLL can be renamed but not deleted. Native rebuilds leave
        # this backup behind so the next process can load the replacement.
        with suppress(OSError):
            library_path.with_name(f"{library_path.name}.previous").unlink()
    if not library_path.is_file():
        raise RuntimeError(
            "原生终端组件不存在："
            f"{library_path}。请先运行对应平台的 packaging/build-native 脚本。"
        )

    with ExitStack() as stack:
        if sys.platform == "win32" and hasattr(os, "add_dll_directory"):
            stack.enter_context(os.add_dll_directory(str(Path(PySide6.__file__).parent)))
            stack.enter_context(os.add_dll_directory(str(library_path.parent)))
        library = ctypes.CDLL(str(library_path))
    register = library.poptools_register_terminal_type
    register.argtypes = []
    register.restype = None
    register()
    _library = library
