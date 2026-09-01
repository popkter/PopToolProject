from __future__ import annotations

import json
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
    QUrl,
    Signal,
    Slot,
)
from PySide6.QtGui import QDesktopServices, QGuiApplication
from PySide6.QtWidgets import QFileDialog

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.paths import package_root
from poptools.runners import ExecutionCoordinator


class SettingsController(QObject):
    """Expose settings and configuration transfer without coupling them to tools."""

    configurationStatusChanged = Signal()
    meritCountChanged = Signal()
    customScriptConcurrencyChanged = Signal()
    themeChanged = Signal()
    terminalEnabledChanged = Signal()
    userGuideSeenChanged = Signal()
    scriptsImported = Signal()
    consoleMessage = Signal(str)

    def __init__(
        self,
        config_store: ConfigStore,
        python_environment: PythonEnvironment,
        execution_coordinator: ExecutionCoordinator | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.config_store = config_store
        self.python_environment = python_environment
        self.execution_coordinator = execution_coordinator
        self._configuration_status = ""
        self._merit_count = config_store.merit_count()
        self._custom_script_concurrency = config_store.custom_script_concurrency()
        self._theme_mode = config_store.theme_mode()
        self._theme_style = config_store.theme_style()
        self._terminal_enabled = config_store.terminal_enabled()
        self._system_dark_theme = False
        self._theme_config_cache: dict[str, str] = {}

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

    @Property(str)
    def pythonExecutable(self) -> str:
        return self.python_environment.state().executable

    @Property(str)
    def pythonEnvironmentStatus(self) -> str:
        return self.python_environment.state().status

    @Property(int, notify=meritCountChanged)
    def meritCount(self) -> int:
        return self._merit_count

    @Property(int, notify=customScriptConcurrencyChanged)
    def customScriptConcurrency(self) -> int:
        return self._custom_script_concurrency

    @Property(str, notify=themeChanged)
    def themeMode(self) -> str:
        return self._theme_mode

    @Property(str, notify=themeChanged)
    def themeStyle(self) -> str:
        return self._theme_style

    @Property(bool, notify=terminalEnabledChanged)
    def terminalEnabled(self) -> bool:
        return self._terminal_enabled

    @Property(bool, notify=userGuideSeenChanged)
    def userGuideSeen(self) -> bool:
        return self.config_store.user_guide_seen()

    @Property(bool, notify=themeChanged)
    def darkTheme(self) -> bool:
        if self._theme_mode == "dark":
            return True
        if self._theme_mode == "light":
            return False
        return self._system_dark_theme

    @Property(str, constant=True)
    def appVersion(self) -> str:
        from poptools import __version__

        return __version__

    @Property(str, constant=True)
    def appInfoUrl(self) -> str:
        return "https://github.com/popkter/PopToolProject"

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
            self.setStatus("本地脚本导入成功，已与现有脚本合并")
            self.consoleMessage.emit("客制脚本导入并合并成功。\n")
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
            self.consoleMessage.emit(f"客制脚本已导出到：{destination}\n")
            return True
        except (OSError, ValueError) as exc:
            self.setStatus(f"本地脚本导出失败：{exc}")
            return False

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

    @Slot()
    def markUserGuideSeen(self) -> None:
        self.config_store.set_user_guide_seen(True)
        self.userGuideSeenChanged.emit()

    @Slot(result=int)
    def addMerit(self) -> int:
        self._merit_count = self.config_store.increment_merit_count()
        self.meritCountChanged.emit()
        return self._merit_count

    @Slot(int, result=bool)
    def saveCustomScriptConcurrency(self, value: int) -> bool:
        try:
            self.config_store.set_custom_script_concurrency(value)
        except (OSError, ValueError) as exc:
            self.setStatus(f"运行配额保存失败：{exc}")
            return False
        self._custom_script_concurrency = value
        if self.execution_coordinator is not None:
            self.execution_coordinator.set_ordinary_limit(value)
        self.customScriptConcurrencyChanged.emit()
        self.setStatus(f"客制脚本同时运行数已设置为 {value}")
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

    @Slot(str, result=bool)
    def saveThemeStyle(self, style: str) -> bool:
        try:
            self.config_store.set_theme_style(style)
        except (OSError, ValueError):
            return False
        if style != self._theme_style:
            self._theme_style = style
            self.themeChanged.emit()
        return True

    @Slot(str, result=str)
    def themeConfigJson(self, style: str) -> str:
        """Return the raw JSON text of a theme config file (configs/<style>.json).

        JSON-driven themes (e.g. mario) read their palette from these files so
        theme colors stay out of ThemeConfig.qml. Cached in memory after first
        read. Returns an empty string if the file is missing or unreadable.
        """
        cached = self._theme_config_cache.get(style)
        if cached is not None:
            return cached
        path = package_root() / "ui" / "qml" / "theme" / "configs" / f"{style}.json"
        if not path.is_file():
            return ""
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            return ""
        self._theme_config_cache[style] = text
        return text

    @Slot(bool, result=bool)
    def saveTerminalEnabled(self, enabled: bool) -> bool:
        try:
            self.config_store.set_terminal_enabled(enabled)
        except OSError as exc:
            self.setStatus(f"终端功能设置保存失败：{exc}")
            return False
        if enabled != self._terminal_enabled:
            self._terminal_enabled = enabled
            self.terminalEnabledChanged.emit()
        self.setStatus("终端功能已开启" if enabled else "终端功能已关闭")
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

    def _documents_directory(self) -> Path:
        value = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DocumentsLocation)
        if value:
            return Path(value)
        return self.config_store.paths.data_dir.parent / "Documents"
