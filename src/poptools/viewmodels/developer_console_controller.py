from __future__ import annotations

import urllib.error
from pathlib import Path

from PySide6.QtCore import (
    Property,
    QObject,
    QThread,
    QTimer,
    Signal,
    Slot,
)

from poptools.infrastructure.conpty import ConPtySession
from poptools.infrastructure.powershell_plugin import PowerShellPlugin
from poptools.infrastructure.python_environment import PythonEnvironment


class PowerShellPluginInstallThread(QThread):
    progressChanged = Signal(int)
    completed = Signal(bool, str)

    def __init__(self, plugin: PowerShellPlugin, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.plugin = plugin

    def run(self) -> None:
        try:
            executable = self.plugin.install(self._report_progress)
        except urllib.error.URLError as exc:
            self.completed.emit(False, f"PowerShell 7 插件下载失败：{exc.reason}")
            return
        except Exception as exc:
            self.completed.emit(False, str(exc))
            return
        self.completed.emit(
            True,
            f"PowerShell {self.plugin.package.version} 安装完成：{executable}",
        )

    def _report_progress(self, progress: int) -> None:
        if self.isInterruptionRequested():
            raise RuntimeError("PowerShell 7 插件安装已取消")
        self.progressChanged.emit(progress)


class DeveloperConsoleController(QObject):
    """Native PowerShell terminal backed by Windows ConPTY."""

    OUTPUT_HISTORY_LIMIT = 131_072

    outputChanged = Signal()
    terminalData = Signal(str)
    terminalResetRequested = Signal()
    runningChanged = Signal()
    pluginStateChanged = Signal()
    pluginInstallPromptRequested = Signal(str, str)
    pluginInstallFinished = Signal(bool, str)
    terminalAccessGranted = Signal()

    def __init__(
        self,
        python_environment: PythonEnvironment,
        working_directory: Path,
        powershell_plugin: PowerShellPlugin | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.python_environment = python_environment
        self.working_directory = working_directory
        self._session: ConPtySession | None = None
        self._output = ""
        self._terminal_ready = False
        self._exit_code = 0
        self._restart_pending = False
        self._shutdown_pending = False
        self._plugin = powershell_plugin or PowerShellPlugin(python_environment.paths)
        self._plugin_install_thread: PowerShellPluginInstallThread | None = None
        self._plugin_install_progress = 0
        self._plugin_install_status = ""

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(bool, notify=runningChanged)
    def running(self) -> bool:
        return self._session is not None

    @Property(str, constant=True)
    def pythonExecutable(self) -> str:
        return self.python_environment.execution_executable() or "不可用"

    @Property(str, constant=True)
    def environmentDirectory(self) -> str:
        return str(self.python_environment.paths.python_venv_dir)

    @Property(bool, notify=pluginStateChanged)
    def pluginInstalled(self) -> bool:
        return self._plugin.is_installed()

    @Property(bool, notify=pluginStateChanged)
    def pluginInstalling(self) -> bool:
        return self._plugin_install_thread is not None

    @Property(int, notify=pluginStateChanged)
    def pluginInstallProgress(self) -> int:
        return self._plugin_install_progress

    @Property(str, notify=pluginStateChanged)
    def pluginInstallStatus(self) -> str:
        return self._plugin_install_status

    @Property(str, constant=True)
    def pluginVersion(self) -> str:
        return self._plugin.package.version

    @Property(str, constant=True)
    def pluginDirectory(self) -> str:
        return str(self._plugin.install_directory)

    @Slot(result=bool)
    def requestTerminalAccess(self) -> bool:
        if self.pluginInstalled:
            self.terminalAccessGranted.emit()
            return True
        self.pluginInstallPromptRequested.emit(
            self.pluginVersion,
            self.pluginDirectory,
        )
        return False

    @Slot(result=bool)
    def installPowerShellPlugin(self) -> bool:
        if self.pluginInstalled:
            self.pluginInstallFinished.emit(True, "PowerShell 7 插件已安装。")
            self.terminalAccessGranted.emit()
            return True
        if self._plugin_install_thread is not None:
            return False
        self._plugin_install_progress = 0
        self._plugin_install_status = "正在下载 PowerShell 7 插件…"
        thread = PowerShellPluginInstallThread(self._plugin, self)
        self._plugin_install_thread = thread
        thread.progressChanged.connect(self._on_plugin_install_progress)
        thread.completed.connect(self._on_plugin_install_completed)
        thread.finished.connect(thread.deleteLater)
        self.pluginStateChanged.emit()
        thread.start()
        return True

    @Slot(result=bool)
    def cancelPowerShellPluginInstall(self) -> bool:
        thread = self._plugin_install_thread
        if thread is None:
            return False
        self._plugin_install_status = "正在取消 PowerShell 7 插件安装…"
        thread.requestInterruption()
        self.pluginStateChanged.emit()
        return True

    @Slot(result=bool)
    def ensureStarted(self) -> bool:
        if self._session is not None:
            return True
        if not self.pluginInstalled:
            self._append("请先安装应用内 PowerShell 7 插件。\n")
            return False
        python_executable = self.python_environment.execution_executable()
        pip_executable = self.python_environment.executable()
        shell = self._plugin.executable
        if not python_executable or not pip_executable:
            self._append("Python 环境不可用，请重新启动应用完成初始化。\n")
            return False
        quoted_python = python_executable.replace("'", "''")
        quoted_pip = pip_executable.replace("'", "''")
        bootstrap = (
            "$OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
            f"function global:python {{ & '{quoted_python}' @args }}; "
            f"function global:pip {{ & '{quoted_pip}' -m pip @args }}; "
            "Import-Module PSReadLine; "
            "Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView"
        )
        environment = self.python_environment.execution_environment()
        environment.update(
            {
                "PYTHONUTF8": "1",
                "PYTHONIOENCODING": "utf-8",
                "PYTHONUNBUFFERED": "1",
                "TERM": "xterm-256color",
            }
        )
        session = ConPtySession(self)
        session.outputReceived.connect(self._on_terminal_output)
        session.processExited.connect(self._on_process_exited)
        session.finished.connect(self._on_session_finished)
        self._session = session
        try:
            session.start_process(
                shell,
                [
                    "-NoLogo",
                    "-NoProfile",
                    "-NoExit",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-Command",
                    bootstrap,
                ],
                self.working_directory,
                environment,
            )
        except Exception as exc:
            self._session = None
            session.dispose()
            session.deleteLater()
            self._append(f"终端启动失败：{exc}\r\n")
            self.runningChanged.emit()
            return False
        self.runningChanged.emit()
        return True

    @Slot(int)
    def _on_plugin_install_progress(self, progress: int) -> None:
        self._plugin_install_progress = progress
        self._plugin_install_status = f"正在安装 PowerShell 7… {progress}%"
        self.pluginStateChanged.emit()

    @Slot(bool, str)
    def _on_plugin_install_completed(self, success: bool, message: str) -> None:
        self._plugin_install_thread = None
        self._plugin_install_status = message
        if success:
            self._plugin_install_progress = 100
        self.pluginStateChanged.emit()
        self.pluginInstallFinished.emit(success, message)
        if success:
            self.terminalAccessGranted.emit()

    @Slot(str, result=bool)
    def writeInput(self, data: str) -> bool:
        if not self.ensureStarted() or self._session is None:
            return False
        return self._session.write(data.encode("utf-8"))

    @Slot(int, int)
    def resizeTerminal(self, columns: int, rows: int) -> None:
        if self._session is not None:
            self._session.resize(columns, rows)

    @Slot()
    def terminalReady(self) -> None:
        self._terminal_ready = True
        if self._output:
            self.terminalData.emit(self._output)
        self.ensureStarted()

    @Slot()
    def terminalDetached(self) -> None:
        self._terminal_ready = False

    @Slot()
    def clear(self) -> None:
        self.writeInput("\x0c")

    @Slot()
    def restart(self) -> None:
        if self._session is None:
            self.ensureStarted()
            return
        self._restart_pending = True
        self._session.stop_process()

    @Slot()
    def stop(self) -> None:
        self._restart_pending = False
        if self._session is not None:
            self._session.stop_process()

    @Slot()
    def shutdown(self) -> None:
        self._shutdown_pending = True
        self.stop()
        session = self._session
        if session is not None:
            if not session.wait(3_000):
                session.dispose()
                session.wait(2_000)
            if self._session is session:
                session.dispose()
                self._session = None
        thread = self._plugin_install_thread
        if thread is not None and thread.isRunning():
            thread.requestInterruption()
            thread.wait()

    @Slot(bytes)
    def _on_terminal_output(self, payload: bytes) -> None:
        self._append(payload.decode("utf-8", errors="replace"))

    @Slot(int)
    def _on_process_exited(self, exit_code: int) -> None:
        self._exit_code = exit_code

    @Slot()
    def _on_session_finished(self) -> None:
        sender = self.sender()
        session = sender if isinstance(sender, ConPtySession) else self._session
        if self._session is session:
            self._session = None
        if session is not None:
            session.dispose()
            session.deleteLater()
        if not self._restart_pending and not self._shutdown_pending:
            self._append(f"\r\nPowerShell 会话已结束（退出码 {self._exit_code}）。\r\n")
        self.runningChanged.emit()
        if self._restart_pending:
            self._restart_pending = False
            self._output = ""
            self.terminalResetRequested.emit()
            QTimer.singleShot(0, self.ensureStarted)

    def _append(self, text: str) -> None:
        if not text:
            return
        self._output = (self._output + text)[-self.OUTPUT_HISTORY_LIMIT :]
        if self._terminal_ready:
            self.terminalData.emit(text)
