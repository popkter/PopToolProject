from __future__ import annotations

import sys
from pathlib import Path
from typing import cast

from PySide6.QtCore import (
    Property,
    QCoreApplication,
    QObject,
    QProcess,
    QStandardPaths,
    Qt,
    QTimer,
    QUrl,
    Signal,
    Slot,
)
from PySide6.QtGui import QDesktopServices, QGuiApplication
from PySide6.QtWidgets import QFileDialog

from poptools.infrastructure.background_process import BackgroundProcess
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import PythonEnvironment


class SettingsController(QObject):
    """Expose settings and configuration transfer without coupling them to tools."""

    configurationStatusChanged = Signal()
    startupWindowSizeChanged = Signal()
    middlePanelColorChanged = Signal()
    pythonEnvironmentChanged = Signal()
    pythonValidationChanged = Signal()
    pythonEnvironmentSaveFinished = Signal(bool)
    themeChanged = Signal()
    scriptsImported = Signal()
    consoleMessage = Signal(str)

    def __init__(
        self,
        config_store: ConfigStore,
        python_environment: PythonEnvironment,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.config_store = config_store
        self.python_environment = python_environment
        self._configuration_status = ""
        self._startup_window_width, self._startup_window_height = config_store.window_size()
        self._startup_window_centered = config_store.window_centered()
        self._middle_panel_color = config_store.middle_panel_color()
        self._theme_mode = config_store.theme_mode()
        self._system_dark_theme = False
        self._python_validation: BackgroundProcess | None = None
        self._python_validation_output = bytearray()
        self._pending_python: tuple[str, str] | None = None

        application = cast(QGuiApplication | None, QGuiApplication.instance())
        if application is not None:
            style_hints = application.styleHints()
            self._system_dark_theme = style_hints.colorScheme() == Qt.ColorScheme.Dark
            style_hints.colorSchemeChanged.connect(self._on_system_color_scheme_changed)

    @Property(str, constant=True)
    def configurationDirectory(self) -> str:
        return str(self.config_store.paths.data_dir.resolve())

    @Property(str, notify=configurationStatusChanged)
    def configurationStatus(self) -> str:
        return self._configuration_status

    @Property(str, notify=pythonEnvironmentChanged)
    def pythonProvider(self) -> str:
        return self.python_environment.state().provider

    @Property(str, notify=pythonEnvironmentChanged)
    def customPythonExecutable(self) -> str:
        return self.config_store.custom_python_executable()

    @Property(str, notify=pythonEnvironmentChanged)
    def pythonExecutable(self) -> str:
        return self.python_environment.state().executable

    @Property(str, notify=pythonEnvironmentChanged)
    def pythonEnvironmentStatus(self) -> str:
        return self.python_environment.state().status

    @Property(bool, notify=pythonValidationChanged)
    def pythonValidationRunning(self) -> bool:
        return self._python_validation is not None

    @Property(int, notify=startupWindowSizeChanged)
    def startupWindowWidth(self) -> int:
        return self._startup_window_width

    @Property(int, notify=startupWindowSizeChanged)
    def startupWindowHeight(self) -> int:
        return self._startup_window_height

    @Property(bool, notify=startupWindowSizeChanged)
    def startupWindowCentered(self) -> bool:
        return self._startup_window_centered

    @Property(str, notify=middlePanelColorChanged)
    def middlePanelColor(self) -> str:
        return self._middle_panel_color

    @Property(str, notify=themeChanged)
    def themeMode(self) -> str:
        return self._theme_mode

    @Property(bool, notify=themeChanged)
    def darkTheme(self) -> bool:
        if self._theme_mode == "dark":
            return True
        if self._theme_mode == "light":
            return False
        return self._system_dark_theme

    @Slot(result=bool)
    def openConfigurationDirectory(self) -> bool:
        directory = self.config_store.paths.data_dir.resolve()
        directory.mkdir(parents=True, exist_ok=True)
        opened = QDesktopServices.openUrl(QUrl.fromLocalFile(str(directory)))
        self.setStatus("已打开配置目录" if opened else "无法打开配置目录")
        return opened

    @Slot(result=bool)
    def importConfiguration(self) -> bool:
        source = QFileDialog.getExistingDirectory(
            None,
            "选择要导入的泡泡工具箱本地脚本目录",
            str(self._documents_directory()),
            QFileDialog.Option.ShowDirsOnly,
        )
        if not source:
            return False
        try:
            self.config_store.import_user_configuration(Path(source))
            self.setStatus("本地脚本导入成功，已应用到默认目录")
            self.consoleMessage.emit("客制功能脚本导入成功。\n")
            self.scriptsImported.emit()
            return True
        except (OSError, ValueError) as exc:
            self.setStatus(f"本地脚本导入失败：{exc}")
            return False

    @Slot(result=bool)
    def exportConfiguration(self) -> bool:
        try:
            destination = self.config_store.export_user_configuration(self._documents_directory())
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(destination)))
            self.setStatus(f"本地脚本已导出到：{destination}")
            self.consoleMessage.emit(f"客制功能脚本已导出到：{destination}\n")
            return True
        except (OSError, ValueError) as exc:
            self.setStatus(f"本地脚本导出失败：{exc}")
            return False

    @Slot(str, str, result=bool)
    def savePythonEnvironment(self, provider: str, custom_executable: str) -> bool:
        if self._python_validation is not None:
            return False
        custom = custom_executable.strip().strip('"')
        if provider == "managed":
            try:
                self.config_store.set_python_environment(provider, custom)
            except (OSError, ValueError) as exc:
                self.setStatus(f"Python 环境保存失败：{exc}")
                return False
            self.pythonEnvironmentChanged.emit()
            self.setStatus(self.python_environment.state().status)
            QTimer.singleShot(0, lambda: self.pythonEnvironmentSaveFinished.emit(True))
            return True
        if provider != "custom" or not custom:
            self.setStatus("Python 环境保存失败：请选择 Python 解释器")
            return False

        process = BackgroundProcess(self)
        process.stdoutReady.connect(self._python_validation_output.extend)
        process.errorOccurred.connect(lambda message: self.setStatus(f"Python 验证失败：{message}"))
        process.finished.connect(self._on_python_validation_finished)
        self._python_validation = process
        self._pending_python = (provider, custom)
        self._python_validation_output.clear()
        self.pythonValidationChanged.emit()
        self.setStatus("正在验证 Python 解释器…")
        source = "import sys; print(sys.version_info.major, sys.version_info.minor)"
        return process.start(custom, ["-c", source])

    @Slot(result=str)
    def choosePythonExecutable(self) -> str:
        selected, _ = QFileDialog.getOpenFileName(
            None,
            "选择 Python 3.11+ 解释器",
            self.customPythonExecutable or self.pythonExecutable,
            "Python 解释器 (python.exe);;所有文件 (*)",
        )
        return selected

    @Slot(result=bool)
    def restartApplication(self) -> bool:
        program = sys.executable
        arguments: list[str] = [] if getattr(sys, "frozen", False) else ["-m", "poptools"]
        result = QProcess.startDetached(program, arguments, str(Path.cwd()))
        started = result[0] if isinstance(result, tuple) else bool(result)
        if not started:
            self.setStatus("应用重启失败，请手动重新打开")
            return False
        QCoreApplication.quit()
        return True

    @Slot(int, int, bool, result=bool)
    def saveStartupWindowSize(self, width: int, height: int, centered: bool) -> bool:
        try:
            self.config_store.set_window_size(width, height)
            self.config_store.set_window_centered(centered)
        except (OSError, ValueError) as exc:
            self.setStatus(f"窗口尺寸保存失败：{exc}")
            return False
        self._startup_window_width = width
        self._startup_window_height = height
        self._startup_window_centered = centered
        self.startupWindowSizeChanged.emit()
        position = "屏幕居中" if centered else "系统默认位置"
        self.setStatus(f"冷启动窗口已保存：{width} × {height}，{position}")
        return True

    @Slot(str, result=bool)
    def saveMiddlePanelColor(self, color: str) -> bool:
        try:
            self.config_store.set_middle_panel_color(color)
        except (OSError, ValueError) as exc:
            self.setStatus(f"中间栏颜色保存失败：{exc}")
            return False
        self._middle_panel_color = self.config_store.middle_panel_color()
        self.middlePanelColorChanged.emit()
        self.setStatus(f"中间栏颜色已保存：{self._middle_panel_color}")
        return True

    @Slot(str, result=bool)
    def saveThemeMode(self, mode: str) -> bool:
        try:
            self.config_store.set_theme_mode(mode)
        except (OSError, ValueError):
            return False
        if mode != self._theme_mode:
            self._theme_mode = mode
            self.themeChanged.emit()
        return True

    def setStatus(self, status: str) -> None:
        if status == self._configuration_status:
            return
        self._configuration_status = status
        self.configurationStatusChanged.emit()

    @Slot(object)
    def _on_system_color_scheme_changed(self, color_scheme: object) -> None:
        dark = color_scheme == Qt.ColorScheme.Dark
        if dark == self._system_dark_theme:
            return
        self._system_dark_theme = dark
        if self._theme_mode == "system":
            self.themeChanged.emit()

    def _on_python_validation_finished(self, exit_code: int) -> None:
        process = self._python_validation
        pending = self._pending_python
        self._python_validation = None
        self._pending_python = None
        self.pythonValidationChanged.emit()
        if process is not None:
            process.deleteLater()
        if pending is None:
            self.pythonEnvironmentSaveFinished.emit(False)
            return
        try:
            version = tuple(int(item) for item in self._python_validation_output.decode().split())
        except ValueError:
            version = ()
        if exit_code != 0 or version < (3, 11):
            self.setStatus("Python 环境保存失败：所选文件不是可用的 Python 3.11+ 解释器")
            self.pythonEnvironmentSaveFinished.emit(False)
            return
        provider, custom = pending
        try:
            self.config_store.set_python_environment(provider, custom)
        except (OSError, ValueError) as exc:
            self.setStatus(f"Python 环境保存失败：{exc}")
            self.pythonEnvironmentSaveFinished.emit(False)
            return
        self.pythonEnvironmentChanged.emit()
        self.setStatus("正在使用自定义 Python 解释器")
        self.consoleMessage.emit(f"Python 环境已更新：{custom}\n")
        self.pythonEnvironmentSaveFinished.emit(True)

    def _documents_directory(self) -> Path:
        value = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DocumentsLocation)
        if value:
            return Path(value)
        return self.config_store.paths.data_dir.parent / "Documents"
