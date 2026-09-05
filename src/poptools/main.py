from __future__ import annotations

import logging
import os
import runpy
import sys
from pathlib import Path
from typing import cast

from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtGui import QFont, QFontDatabase, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from poptools import __version__
from poptools.application import build_components
from poptools.infrastructure.app_logging import configure_application_logging
from poptools.infrastructure.python_environment import prepare_managed_python
from poptools.infrastructure.single_instance import SingleInstanceLock
from poptools.infrastructure.system_tray import SystemTrayController
from poptools.infrastructure.windows_integration import (
    apply_windows_window_effects,
    apply_windows_window_icon,
    configure_windows_app_identity,
)
from poptools.native_terminal import register_terminal_type
from poptools.paths import AppPaths, package_root, prepare_bundled_android_tools, resource_path


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
    QCoreApplication.setApplicationVersion(__version__)
    paths = AppPaths.from_environment()
    logging_session = configure_application_logging(paths)
    logger = logging.getLogger(__name__)
    logger.info("应用正在启动")
    instance_lock = SingleInstanceLock(paths.data_dir / "poptools.lock")
    if not instance_lock.try_acquire():
        logger.info("已有实例运行，转为激活现有窗口")
        instance_lock.activate_running_instance()
        logging_session.close()
        return 0

    try:
        app = QApplication(sys.argv)
        if sys.platform == "win32":
            register_terminal_type()
        if not instance_lock.start_activation_server():
            logger.error("无法启动单实例激活服务")
            return 1
        app.setFont(QFont("Microsoft YaHei UI" if sys.platform == "win32" else "PingFang SC", 10))

        icon_font = resource_path("fonts", "MaterialIconsRound-Regular.otf")
        if icon_font.exists():
            QFontDatabase.addApplicationFont(str(icon_font))

        tray_controller = SystemTrayController(app)
        app.commitDataRequest.connect(
            lambda _session_manager: tray_controller.quit_application()
        )
        app.setWindowIcon(tray_controller.icon)

        prepare_bundled_android_tools(paths)
        python_setup_error = ""
        if getattr(sys, "frozen", False):
            try:
                prepare_managed_python(paths)
            except (OSError, RuntimeError, ValueError) as exc:
                python_setup_error = str(exc)
                logger.exception("Python 环境初始化失败")
        components = build_components(paths)
        controller = components.app_controller
        android_controller = components.android_controller
        settings_controller = components.settings_controller
        preset_controller = components.preset_controller
        jira_feishu_controller = components.jira_feishu_controller
        developer_console_controller = components.developer_console_controller
        platform_ui_controller = components.platform_ui_controller
        update_controller = components.update_controller
        app.aboutToQuit.connect(developer_console_controller.shutdown)
        app.aboutToQuit.connect(update_controller.shutdown)
        app.aboutToQuit.connect(jira_feishu_controller.shutdown)
        tray_controller.set_app_controller(controller)
        if python_setup_error:
            settings_controller.setStatus(f"Python 环境初始化失败：{python_setup_error}")

        engine = QQmlApplicationEngine()
        engine.rootContext().setContextProperty("appController", controller)
        engine.rootContext().setContextProperty("settingsController", settings_controller)
        engine.rootContext().setContextProperty("presetController", preset_controller)
        engine.rootContext().setContextProperty(
            "jiraFeishuController", jira_feishu_controller
        )
        engine.rootContext().setContextProperty(
            "developerConsoleController", developer_console_controller
        )
        engine.rootContext().setContextProperty("androidController", android_controller)
        engine.rootContext().setContextProperty("trayController", tray_controller)
        engine.rootContext().setContextProperty("updateController", update_controller)
        engine.rootContext().setContextProperty(
            "platformUiController", platform_ui_controller
        )
        qml_file = package_root() / "ui" / "qml" / "Main.qml"
        engine.load(QUrl.fromLocalFile(str(qml_file)))
        if not engine.rootObjects():
            logger.error("QML 主窗口加载失败：%s", qml_file)
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
        exit_code = app.exec()
        logger.info("应用正常退出，退出码：%s", exit_code)
        return exit_code
    finally:
        instance_lock.release()
        logging_session.close()


if __name__ == "__main__":
    raise SystemExit(main())
