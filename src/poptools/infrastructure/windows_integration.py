from __future__ import annotations

import ctypes
import sys

APP_USER_MODEL_ID = "PopTools.ZhangPaopaoToolbox"
_WM_SETICON = 0x0080
_ICON_SMALL = 0
_ICON_BIG = 1
_IMAGE_ICON = 1
_LR_LOADFROMFILE = 0x0010
_GCLP_HICON = -14
_GCLP_HICONSM = -34
_NATIVE_ICON_HANDLES: list[int] = []
_DWMWA_NCRENDERING_POLICY = 2
_DWMNCRP_ENABLED = 2
_DWMWA_WINDOW_CORNER_PREFERENCE = 33
_DWMWCP_ROUND = 2
_DWMWA_BORDER_COLOR = 34
_WINDOW_BORDER_COLOR = 0x00E7DEE2
_GWL_STYLE = -16
_WS_THICKFRAME = 0x00040000
_SWP_NOSIZE = 0x0001
_SWP_NOMOVE = 0x0002
_SWP_NOZORDER = 0x0004
_SWP_NOACTIVATE = 0x0010
_SWP_FRAMECHANGED = 0x0020


class _Margins(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_int),
        ("right", ctypes.c_int),
        ("top", ctypes.c_int),
        ("bottom", ctypes.c_int),
    ]


def configure_windows_app_identity() -> None:
    if sys.platform != "win32":
        return
    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    result = shell32.SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID)
    if result != 0:
        raise OSError(result, "无法设置 Windows 应用标识")


def apply_windows_window_icon(window_id: int, icon_path: str) -> None:
    if sys.platform != "win32":
        return
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    hwnd = ctypes.c_void_p(window_id)
    user32.LoadImageW.argtypes = [
        ctypes.c_void_p,
        ctypes.c_wchar_p,
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_uint,
    ]
    user32.LoadImageW.restype = ctypes.c_void_p
    user32.SendMessageW.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_size_t,
        ctypes.c_ssize_t,
    ]
    user32.SendMessageW.restype = ctypes.c_ssize_t
    user32.SetClassLongPtrW.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_ssize_t]
    user32.SetClassLongPtrW.restype = ctypes.c_ssize_t
    large = user32.LoadImageW(None, icon_path, _IMAGE_ICON, 0, 0, _LR_LOADFROMFILE)
    small = user32.LoadImageW(None, icon_path, _IMAGE_ICON, 16, 16, _LR_LOADFROMFILE)
    if not large or not small:
        raise OSError(ctypes.get_last_error(), "无法加载 Windows 应用图标")
    _NATIVE_ICON_HANDLES.extend((int(large), int(small)))
    user32.SendMessageW(hwnd, _WM_SETICON, _ICON_BIG, large)
    user32.SendMessageW(hwnd, _WM_SETICON, _ICON_SMALL, small)
    user32.SetClassLongPtrW(hwnd, _GCLP_HICON, large)
    user32.SetClassLongPtrW(hwnd, _GCLP_HICONSM, small)

def apply_windows_window_effects(window_id: int) -> None:
    if sys.platform != "win32":
        return
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    dwmapi = ctypes.WinDLL("dwmapi", use_last_error=True)
    hwnd = ctypes.c_void_p(window_id)
    user32.GetWindowLongPtrW.argtypes = [ctypes.c_void_p, ctypes.c_int]
    user32.GetWindowLongPtrW.restype = ctypes.c_ssize_t
    user32.SetWindowLongPtrW.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_ssize_t]
    user32.SetWindowLongPtrW.restype = ctypes.c_ssize_t
    style = user32.GetWindowLongPtrW(hwnd, _GWL_STYLE)
    user32.SetWindowLongPtrW(hwnd, _GWL_STYLE, style | _WS_THICKFRAME)
    frame_flags = (
        _SWP_NOSIZE | _SWP_NOMOVE | _SWP_NOZORDER | _SWP_NOACTIVATE | _SWP_FRAMECHANGED
    )
    user32.SetWindowPos(hwnd, None, 0, 0, 0, 0, frame_flags)
    dwmapi.DwmSetWindowAttribute.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_void_p,
        ctypes.c_uint,
    ]
    dwmapi.DwmSetWindowAttribute.restype = ctypes.c_long
    policy = ctypes.c_int(_DWMNCRP_ENABLED)
    dwmapi.DwmSetWindowAttribute(
        hwnd, _DWMWA_NCRENDERING_POLICY, ctypes.byref(policy), ctypes.sizeof(policy)
    )
    if sys.getwindowsversion().build >= 22000:
        corner = ctypes.c_int(_DWMWCP_ROUND)
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            _DWMWA_WINDOW_CORNER_PREFERENCE,
            ctypes.byref(corner),
            ctypes.sizeof(corner),
        )
        border = ctypes.c_uint(_WINDOW_BORDER_COLOR)
        dwmapi.DwmSetWindowAttribute(
            hwnd, _DWMWA_BORDER_COLOR, ctypes.byref(border), ctypes.sizeof(border)
        )
    dwmapi.DwmExtendFrameIntoClientArea.argtypes = [ctypes.c_void_p, ctypes.POINTER(_Margins)]
    dwmapi.DwmExtendFrameIntoClientArea.restype = ctypes.c_long
    margins = _Margins(1, 1, 1, 1)
    dwmapi.DwmExtendFrameIntoClientArea(hwnd, ctypes.byref(margins))