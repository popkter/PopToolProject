from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path
from typing import cast

from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtGui import QFont, QFontDatabase, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.python_environment import PythonEnvironment, prepare_managed_python
from poptools.infrastructure.single_instance import SingleInstanceLock
from poptools.infrastructure.system_tray import SystemTrayController
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.infrastructure.windows_integration import (
    apply_windows_window_effects,
    apply_windows_window_icon,
    configure_windows_app_identity,
)
from poptools.paths import AppPaths, package_root, prepare_bundled_android_tools, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import (
    AndroidController,
    AppController,
    PresetController,
    SettingsController,
)


def _run_worker(arguments: list[str]) -> int:
    if not arguments:
        print("worker script is required", file=sys.stderr)
        return 2
    script = Path(arguments[0]).resolve()
    sys.argv = [str(script), *arguments[1:]]
    try:
        runpy.run_path(str(script), run_name="__main__")
    except SystemExit as exc:
        return int(exc.code or 0)
    except Exception as exc:
        print(f"worker failed: {exc}", file=sys.stderr)
        return 1
    return 0


def _run_worker_code(arguments: list[str]) -> int:
    if not arguments:
        print("worker source is required", file=sys.stderr)
        return 2
    source = arguments[0]
    sys.argv = ["<poptools-inline>", *arguments[1:]]
    namespace = {"__name__": "__main__", "__file__": "<poptools-inline>", "__package__": None}
    try:
        exec(compile(source, "<poptools-inline>", "exec"), namespace)
    except SystemExit as exc:
        return int(exc.code or 0)
    except Exception as exc:
        print(f"worker failed: {exc}", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    if "--worker-code" in sys.argv:
        index = sys.argv.index("--worker-code")
        return _run_worker_code(sys.argv[index + 1 :])

    if "--worker" in sys.argv:
        index = sys.argv.index("--worker")
        return _run_worker(sys.argv[index + 1 :])

    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    configure_windows_app_identity()
    QCoreApplication.setOrganizationName("PopTools")
    QCoreApplication.setApplicationName("泡泡工具箱")
    paths = AppPaths.from_environment()
    instance_lock = SingleInstanceLock(paths.data_dir / "poptools.lock")
    if not instance_lock.try_acquire():
        instance_lock.activate_running_instance()
        return 0

    try:
        app = QApplication(sys.argv)
        if not instance_lock.start_activation_server():
            return 1
        app.setFont(QFont("Microsoft YaHei UI", 10))

        icon_font = resource_path("fonts", "MaterialIconsRound-Regular.otf")
        if icon_font.exists():
            QFontDatabase.addApplicationFont(str(icon_font))

        tray_controller = SystemTrayController(app)
        app.setWindowIcon(tray_controller.icon)

        prepare_bundled_android_tools(paths)
        config_store = ConfigStore(paths)
        config_store.load_config()
        python_setup_error = ""
        python_provider, _ = config_store.python_environment()
        if getattr(sys, "frozen", False) and python_provider == "managed":
            try:
                prepare_managed_python(paths)
            except (OSError, RuntimeError, ValueError) as exc:
                python_setup_error = str(exc)
        python_environment = PythonEnvironment(paths, config_store)
        tool_repository = JsonToolRepository(paths)
        registry = ToolRegistry(resource_path("tools"), tool_repository)
        execution = ExecutionManager(paths, python_environment)
        execution_coordinator = ExecutionCoordinator(
            execution,
            config_store.max_parallel(),
        )
        android_controller = AndroidController(config_store)
        controller = AppController(
            registry,
            execution_coordinator,
            config_store,
            android_controller,
        )
        settings_controller = SettingsController(config_store, python_environment)
        preset_controller = PresetController()
        settings_controller.scriptsImported.connect(controller.reloadImportedScripts)
        settings_controller.consoleMessage.connect(controller.appendConsoleMessage)
        if python_setup_error:
            settings_controller.setStatus(f"Python 环境初始化失败：{python_setup_error}")

        engine = QQmlApplicationEngine()
        engine.rootContext().setContextProperty("appController", controller)
        engine.rootContext().setContextProperty("settingsController", settings_controller)
        engine.rootContext().setContextProperty("presetController", preset_controller)
        engine.rootContext().setContextProperty("androidController", android_controller)
        engine.rootContext().setContextProperty("trayController", tray_controller)
        qml_file = package_root() / "ui" / "qml" / "Main.qml"
        engine.load(QUrl.fromLocalFile(str(qml_file)))
        if not engine.rootObjects():
            return 1
        window = cast(QWindow, engine.rootObjects()[0])
        window.setIcon(tray_controller.icon)
        apply_windows_window_icon(
            int(window.winId()), str(resource_path("icons", "app-icon.ico"))
        )
        apply_windows_window_effects(int(window.winId()))
        tray_controller.attach_window(window)
        instance_lock.set_activation_handler(tray_controller.show_window)
        controller.attach_window(window)
        return app.exec()
    finally:
        instance_lock.release()


if __name__ == "__main__":
    raise SystemExit(main())
