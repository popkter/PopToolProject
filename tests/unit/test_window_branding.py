from pathlib import Path

PROJECT_ROOT = Path(__file__).parents[2]


def test_main_window_uses_custom_title_bar_and_cat_brand_icon() -> None:
    qml = (PROJECT_ROOT / "src" / "poptools" / "ui" / "qml" / "Main.qml").read_text(
        encoding="utf-8"
    )

    assert "Qt.FramelessWindowHint" in qml
    assert "Qt.CustomizeWindowHint" not in qml
    assert "id: customTitleBar" in qml
    assert "window.startSystemMove()" in qml
    assert "window.startSystemResize(resizeEdges)" in qml
    assert "Qt.BottomEdge | Qt.RightEdge" in qml
    assert "radius: window.visibility === Window.Maximized ? 0 : 10" in qml
    assert "border.color: Theme.outlineVariant" in qml
    assert "window.showMinimized()" in qml
    assert "window.showMaximized()" in qml
    assert "window.showNormal()" in qml
    assert "window.close()" in qml
    assert 'source: Qt.resolvedUrl("../../resources/icons/app-icon.png")' in qml
    assert 'icon: "build"' not in qml


def test_windows_identity_matches_installed_shortcuts() -> None:
    integration = (
        PROJECT_ROOT / "src" / "poptools" / "infrastructure" / "windows_integration.py"
    ).read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "src" / "poptools" / "main.py").read_text(encoding="utf-8")
    installer = (PROJECT_ROOT / "packaging" / "poptools.iss").read_text(encoding="utf-8")

    assert 'APP_USER_MODEL_ID = "PopTools.ZhangPaopaoToolbox"' in integration
    assert "configure_windows_app_identity()" in main
    assert "window.setIcon(tray_controller.icon)" in main
    assert "apply_windows_window_icon(" in main
    assert "apply_windows_window_effects(int(window.winId()))" in main
    assert 'app.setFont(QFont("Microsoft YaHei UI", 10))' in main
    assert "_DWMWA_WINDOW_CORNER_PREFERENCE = 33" in integration
    assert "dwmapi.DwmExtendFrameIntoClientArea" in integration
    assert "_WS_THICKFRAME = 0x00040000" in integration
    assert "user32.SetClassLongPtrW(hwnd, _GCLP_HICON, large)" in integration
    assert "user32.SetClassLongPtrW(hwnd, _GCLP_HICONSM, small)" in integration
    assert 'AppUserModelID: "{#MyAppUserModelId}"' in installer

def test_windows_app_identity_is_applied() -> None:
    import sys

    if sys.platform != "win32":
        return

    import ctypes

    from poptools.infrastructure.windows_integration import (
        APP_USER_MODEL_ID,
        configure_windows_app_identity,
    )

    configure_windows_app_identity()
    current_app_id = ctypes.c_wchar_p()
    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    result = shell32.GetCurrentProcessExplicitAppUserModelID(ctypes.byref(current_app_id))
    try:
        assert result == 0
        assert current_app_id.value == APP_USER_MODEL_ID
    finally:
        ctypes.windll.ole32.CoTaskMemFree(current_app_id)