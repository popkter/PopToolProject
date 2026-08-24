from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import cast

from PySide6.QtCore import QMetaObject, QTimer, QUrl
from PySide6.QtGui import QFont, QFontDatabase, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWebEngineQuick import QtWebEngineQuick
from PySide6.QtWidgets import QApplication

from poptools.infrastructure.app_updater import UpdateRelease
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
    DeveloperConsoleController,
    PresetController,
    SettingsController,
    UpdateController,
)


def main() -> int:
    output_path = Path(sys.argv[1] if len(sys.argv) > 1 else "implementation.png").resolve()
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    QtWebEngineQuick.initialize()
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
    if os.environ.get("POPTOOLS_CAPTURE_GRID_SAMPLE") == "1":
        samples = (
            ("挂载设备", "使用 Remount 挂载 Android 设备", "batch"),
            ("同步时间到设备", "同步电脑时间并校准设备时钟", "powershell"),
            ("点亮 EX-G 屏幕", "唤醒并点亮测试设备屏幕", "python"),
            ("开启点按位置", "显示设备触摸点与坐标", "batch"),
            ("清除本地 CRASH 计数", "清理本地崩溃统计数据", "powershell"),
            ("发送文本到 ASR", "向语音识别服务发送测试文本", "python"),
            ("打开系统设置", "快速打开 Android 系统设置", "batch"),
            ("监听设备进程", "持续观察目标进程运行状态", "powershell"),
            ("查看进程 dumpsys 信息", "读取进程诊断与内存信息", "batch"),
            ("设置台架环境", "配置台架设备与网络参数", "python"),
            ("导出设备日志", "收集并导出当前设备日志", "powershell"),
            ("检查网络连接", "验证设备网络与服务连通性", "batch"),
        )
        for title, description, kind in samples:
            registry.create_custom(
                title=title,
                description=description,
                kind=kind,
                command="Write-Output preview",
            )
    python_environment = PythonEnvironment(paths, config_store)
    execution = ExecutionManager(paths, python_environment)
    coordinator = ExecutionCoordinator(execution, config_store.max_parallel())
    android_controller = AndroidController(config_store)
    controller = AppController(registry, coordinator, config_store, android_controller)
    settings_controller = SettingsController(config_store, python_environment, coordinator)
    if os.environ.get("POPTOOLS_CAPTURE_GRID_SAMPLE") == "1":
        settings_controller.markUserGuideSeen()
    preset_controller = PresetController()
    developer_console_controller = DeveloperConsoleController(python_environment, paths.data_dir)
    app.aboutToQuit.connect(developer_console_controller.shutdown)
    capture_terminal_tabs = int(os.environ.get("POPTOOLS_CAPTURE_TERMINAL_TABS", "1"))
    for _ in range(max(1, min(capture_terminal_tabs, 7)) - 1):
        developer_console_controller.createTerminalTab()
    update_controller = UpdateController(config_store, auto_check_enabled=False)
    if len(sys.argv) > 2 and sys.argv[2] in {"developer", "powershell-plugin", "update"}:
        settings_controller.markUserGuideSeen()
    if len(sys.argv) > 2 and sys.argv[2] == "update":
        update_controller._on_check_completed(
            UpdateRelease(
                version="0.2.0",
                tag="v0.2.0",
                name="泡泡工具箱 0.2.0",
                notes="新增应用内自动更新功能。\n\n修复已知问题并优化启动性能。",
                page_url="https://github.com/popkter/PopToolProject/releases/tag/v0.2.0",
                asset_url="https://example.test/app.exe",
                asset_name="泡泡工具箱.exe",
                asset_size=191_000_000,
            ),
            "",
        )
    capture_theme = os.environ.get("POPTOOLS_CAPTURE_THEME", "").strip()
    if capture_theme:
        settings_controller.saveThemeMode(capture_theme)
    settings_controller.scriptsImported.connect(controller.reloadImportedScripts)
    settings_controller.consoleMessage.connect(controller.appendConsoleMessage)
    tray_controller = SystemTrayController(app)
    if len(sys.argv) > 2 and sys.argv[2] not in {"developer", "powershell-plugin", "update"}:
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
    engine.rootContext().setContextProperty(
        "developerConsoleController", developer_console_controller
    )
    engine.rootContext().setContextProperty("androidController", android_controller)
    engine.rootContext().setContextProperty("trayController", tray_controller)
    engine.rootContext().setContextProperty("updateController", update_controller)
    engine.load(QUrl.fromLocalFile(str(package_root() / "ui" / "qml" / "Main.qml")))
    if not engine.rootObjects():
        print("\n".join(qml_warnings), file=sys.stderr)
        return 1
    window = cast(QWindow, engine.rootObjects()[0])
    if len(sys.argv) > 2 and sys.argv[2] == "developer":
        window.setProperty("developerSelected", True)
    elif len(sys.argv) > 2 and sys.argv[2] == "powershell-plugin":
        QTimer.singleShot(100, developer_console_controller.requestTerminalAccess)
    tray_controller.attach_window(window)
    controller.attach_window(window)
    capture_size = os.environ.get("POPTOOLS_CAPTURE_SIZE", "")
    if "x" in capture_size:
        capture_width, capture_height = capture_size.lower().split("x", maxsplit=1)
        window.setWidth(int(capture_width))
        window.setHeight(int(capture_height))
        window.setX(0)
        window.setY(0)
    if os.environ.get("POPTOOLS_CAPTURE_CUSTOM_DRAWER") == "1":
        custom_tools = registry.for_section("custom")
        if custom_tools:
            controller.selectTool(custom_tools[0].id)
    capture_dialog = os.environ.get("POPTOOLS_CAPTURE_DIALOG")
    if capture_dialog == "settings":
        window.openSettingsDialog()
    if capture_dialog == "update":
        QTimer.singleShot(250, lambda: QMetaObject.invokeMethod(window, "queueUpdateDialog"))

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
