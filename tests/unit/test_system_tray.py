from __future__ import annotations

import os
from pathlib import Path

from PySide6.QtWidgets import QApplication

from poptools.infrastructure.system_tray import SystemTrayController, create_app_icon

PROJECT_ROOT = Path(__file__).parents[2]


class FakeWindow:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def show(self) -> None:
        self.calls.append("show")

    def showNormal(self) -> None:  # noqa: N802
        self.calls.append("showNormal")

    def raise_(self) -> None:
        self.calls.append("raise")

    def requestActivate(self) -> None:  # noqa: N802
        self.calls.append("activate")

    def close(self) -> None:
        self.calls.append("close")


def test_tray_menu_can_restore_window_and_exit() -> None:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = QApplication.instance() or QApplication([])
    controller = SystemTrayController(app)
    window = FakeWindow()
    controller._window = window  # type: ignore[assignment]  # noqa: SLF001

    assert [action.text() for action in controller._menu.actions()] == [  # noqa: SLF001
        "显示主界面",
        "预置功能",
        "最近使用",
        "",
        "退出",
    ]

    controller._show_action.trigger()  # noqa: SLF001
    controller._exit_action.trigger()  # noqa: SLF001

    assert window.calls == ["show", "showNormal", "raise", "activate", "close"]
    assert controller.quitting is True


def test_close_button_is_routed_to_tray_when_available() -> None:
    source = (PROJECT_ROOT / "src" / "poptools" / "ui" / "qml" / "Main.qml").read_text(
        encoding="utf-8"
    )

    assert "onClosing: function (close)" in source
    assert "trayController.available && !trayController.quitting" in source
    assert "close.accepted = false" in source
    assert "trayController.notify_hidden()" in source


def test_pyinstaller_spec_builds_one_self_contained_executable() -> None:
    source = (PROJECT_ROOT / "packaging" / "poptools.spec").read_text(encoding="utf-8")

    assert "analysis.binaries" in source
    assert "analysis.datas" in source
    assert "exclude_binaries=False" in source
    assert "COLLECT(" not in source
    assert 'icon=str(PACKAGE / "resources" / "icons" / "app-icon.ico")' in source


def test_app_icon_assets_are_available() -> None:
    icon_dir = PROJECT_ROOT / "src" / "poptools" / "resources" / "icons"

    assert (icon_dir / "app-icon.png").is_file()
    assert (icon_dir / "app-icon.ico").is_file()
    assert not create_app_icon().isNull()
