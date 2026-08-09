from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import cast

from PySide6.QtCore import QObject, QTimer, QUrl
from PySide6.QtGui import QFont, QFontDatabase, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.infrastructure.system_tray import SystemTrayController
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, package_root, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import (
    AndroidController,
    AppController,
    PresetController,
    SettingsController,
)


def main() -> int:
    output_path = Path(sys.argv[1] if len(sys.argv) > 1 else "implementation.png").resolve()
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    app = QApplication(sys.argv)
    system_font = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / "msyh.ttc"
    if system_font.exists():
        QFontDatabase.addApplicationFont(str(system_font))
    app.setFont(QFont("Microsoft YaHei UI", 10))
    icon_font = resource_path("fonts", "MaterialIconsRound-Regular.otf")
    if icon_font.exists():
        QFontDatabase.addApplicationFont(str(icon_font))

    paths = AppPaths.from_environment()
    config_store = ConfigStore(paths)
    config_store.load_config()
    repository = JsonToolRepository(paths)
    registry = ToolRegistry(resource_path("tools"), repository)
    python_environment = PythonEnvironment(paths, config_store)
    execution = ExecutionManager(paths, python_environment)
    coordinator = ExecutionCoordinator(execution, config_store.max_parallel())
    android_controller = AndroidController(config_store)
    controller = AppController(registry, coordinator, config_store, android_controller)
    settings_controller = SettingsController(config_store, python_environment)
    preset_controller = PresetController()
    capture_theme = os.environ.get("POPTOOLS_CAPTURE_THEME", "").strip()
    if capture_theme:
        settings_controller.saveThemeMode(capture_theme)
    settings_controller.scriptsImported.connect(controller.reloadImportedScripts)
    settings_controller.consoleMessage.connect(controller.appendConsoleMessage)
    tray_controller = SystemTrayController(app)
    if len(sys.argv) > 2:
        controller.navigate(sys.argv[2])
    if len(sys.argv) > 3:
        if sys.argv[3] == "__dynamic__":
            tool = registry.create_custom(
                title="ADB 密码命令",
                description="使用动态密码参数执行 ADB 命令",
                kind="powershell",
                command="adb shell ${输入密码}",
            )
            controller.selectTool(tool.id)
        else:
            controller.selectTool(sys.argv[3])
    engine = QQmlApplicationEngine()
    qml_warnings: list[str] = []
    engine.warnings.connect(
        lambda warnings: qml_warnings.extend(warning.toString() for warning in warnings)
    )
    engine.rootContext().setContextProperty("appController", controller)
    engine.rootContext().setContextProperty("settingsController", settings_controller)
    engine.rootContext().setContextProperty("presetController", preset_controller)
    engine.rootContext().setContextProperty("androidController", android_controller)
    engine.rootContext().setContextProperty("trayController", tray_controller)
    engine.load(QUrl.fromLocalFile(str(package_root() / "ui" / "qml" / "Main.qml")))
    if not engine.rootObjects():
        print("\n".join(qml_warnings), file=sys.stderr)
        return 1
    window = cast(QWindow, engine.rootObjects()[0])
    tray_controller.attach_window(window)
    controller.attach_window(window)
    capture_size = os.environ.get("POPTOOLS_CAPTURE_SIZE", "")
    if "x" in capture_size:
        capture_width, capture_height = capture_size.lower().split("x", maxsplit=1)
        window.setWidth(int(capture_width))
        window.setHeight(int(capture_height))
    if os.environ.get("POPTOOLS_CAPTURE_DIALOG") == "settings":
        settings_dialog = window.findChild(QObject, "settingsDialog")
        if settings_dialog is not None:
            QTimer.singleShot(100, settings_dialog.open)

    def capture() -> None:
        screen = window.screen() or app.primaryScreen()
        image = screen.grabWindow(window.winId()).toImage()
        if image.isNull() or not image.save(str(output_path)):
            app.exit(2)
            return
        app.quit()

    QTimer.singleShot(1500, capture)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
