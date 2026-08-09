from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtGui import QIcon, QWindow
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from poptools.paths import resource_path


def create_app_icon() -> QIcon:
    icon = QIcon(str(resource_path("icons", "app-icon.ico")))
    if icon.isNull():
        raise RuntimeError("应用图标资源无法加载")
    return icon


class SystemTrayController(QObject):
    quittingChanged = Signal()

    def __init__(self, app: QApplication) -> None:
        super().__init__(app)
        self._app = app
        self._window: QWindow | None = None
        self._quitting = False
        self._notified = False
        self._available = QSystemTrayIcon.isSystemTrayAvailable()
        self.icon = create_app_icon()
        self._tray = QSystemTrayIcon(self.icon, self)
        self._tray.setToolTip("泡泡工具箱")
        self._menu = QMenu()
        self._show_action = self._menu.addAction("显示主界面")
        self._show_action.triggered.connect(self.show_window)
        self._menu.addSeparator()
        self._exit_action = self._menu.addAction("退出")
        self._exit_action.triggered.connect(self.quit_application)
        self._tray.setContextMenu(self._menu)
        self._tray.activated.connect(self._on_activated)
        if self._available:
            self._app.setQuitOnLastWindowClosed(False)
            self._tray.show()

    @Property(bool, constant=True)
    def available(self) -> bool:
        return self._available

    @Property(bool, notify=quittingChanged)
    def quitting(self) -> bool:
        return self._quitting

    def attach_window(self, window: QWindow) -> None:
        self._window = window

    @Slot()
    def notify_hidden(self) -> None:
        if not self._available or self._notified:
            return
        self._notified = True
        self._tray.showMessage(
            "泡泡工具箱 已最小化到托盘",
            "右键托盘图标可以显示主界面或退出。",
            QSystemTrayIcon.MessageIcon.Information,
            3000,
        )

    @Slot()
    def show_window(self) -> None:
        if self._window is None:
            return
        self._window.show()
        self._window.showNormal()
        self._window.raise_()
        self._window.requestActivate()

    @Slot()
    def quit_application(self) -> None:
        if self._quitting:
            return
        self._quitting = True
        self.quittingChanged.emit()
        self._tray.hide()
        if self._window is not None:
            self._window.close()
        self._app.quit()

    def _on_activated(self, reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason in {
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
        }:
            self.show_window()
