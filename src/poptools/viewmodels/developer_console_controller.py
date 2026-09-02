from __future__ import annotations

import codecs
import os
import sys
import urllib.error
from dataclasses import dataclass, field
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
from poptools.paths import bundled_adb_path, resource_path


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


@dataclass
class TerminalTabState:
    tab_id: str
    title: str
    session: ConPtySession | None = None
    output: str = ""
    exit_code: int = 0
    restart_pending: bool = False
    intentional_stop: bool = False
    output_decoder: codecs.IncrementalDecoder = field(
        default_factory=lambda: codecs.getincrementaldecoder("utf-8")(errors="replace")
    )


class DeveloperConsoleController(QObject):
    """Native terminal backed by Windows ConPTY or a macOS POSIX PTY."""

    OUTPUT_HISTORY_LIMIT = 131_072

    outputChanged = Signal()
    terminalData = Signal(str, str)
    terminalSnapshotData = Signal(str, str)
    terminalResetRequested = Signal(str)
    terminalSessionRemoved = Signal(str)
    runningChanged = Signal()
    pluginStateChanged = Signal()
    pluginInstallPromptRequested = Signal(str, str)
    pluginInstallFinished = Signal(bool, str)
    terminalAccessGranted = Signal()
    terminalTabsChanged = Signal()

    MAX_TERMINAL_TABS = 7

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
        self._tabs: list[TerminalTabState] = []
        self._closing_tabs: dict[str, TerminalTabState] = {}
        self._active_tab_id = ""
        self._next_tab_number = 1
        self._terminal_ready = False
        self._terminal_columns = 120
        self._terminal_rows = 30
        self._shutdown_pending = False
        self._plugin = powershell_plugin
        if self._plugin is None and sys.platform == "win32":
            self._plugin = PowerShellPlugin(python_environment.paths)
        self._plugin_install_thread: PowerShellPluginInstallThread | None = None
        self._plugin_install_progress = 0
        self._plugin_install_status = ""
        self._create_tab(activate=True)

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        tab = self._active_tab()
        return tab.output if tab is not None else ""

    @Property(bool, notify=runningChanged)
    def running(self) -> bool:
        tab = self._active_tab()
        return tab is not None and tab.session is not None

    @Property(list, notify=terminalTabsChanged)
    def terminalTabs(self) -> list[dict[str, object]]:
        return [
            {
                "tabId": tab.tab_id,
                "title": tab.title,
                "active": tab.tab_id == self._active_tab_id,
                "running": tab.session is not None,
            }
            for tab in self._tabs
        ]

    @Property(str, notify=terminalTabsChanged)
    def activeTerminalTabId(self) -> str:
        return self._active_tab_id

    @Property(bool, notify=terminalTabsChanged)
    def canCreateTerminalTab(self) -> bool:
        return len(self._tabs) < self.MAX_TERMINAL_TABS

    @Property(str, constant=True)
    def pythonExecutable(self) -> str:
        return self.python_environment.execution_executable() or "不可用"

    @Property(str, constant=True)
    def environmentDirectory(self) -> str:
        return str(self.python_environment.paths.python_venv_dir)

    @Property(bool, notify=pluginStateChanged)
    def pluginInstalled(self) -> bool:
        return self._plugin is None or self._plugin.is_installed()

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
        return self._plugin.package.version if self._plugin is not None else "macOS Shell"

    @Property(str, constant=True)
    def pluginDirectory(self) -> str:
        return str(self._plugin.install_directory) if self._plugin is not None else ""

    @Property(str, constant=True)
    def terminalName(self) -> str:
        return self._terminal_name()

    @staticmethod
    def _terminal_name() -> str:
        return "PowerShell 7" if sys.platform == "win32" else "macOS Shell"

    @Property(int, constant=True)
    def windowsBuildNumber(self) -> int:
        if sys.platform != "win32":
            return 0
        return int(sys.getwindowsversion().build)

    @Slot(result=bool)
    def requestTerminalAccess(self) -> bool:
        if self._plugin is None:
            self.terminalAccessGranted.emit()
            return True
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
        if self._plugin is None:
            self.terminalAccessGranted.emit()
            return True
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
        tab = self._active_tab()
        if tab is None:
            tab = self._create_tab(activate=True)
        return self._ensure_tab_started(tab)

    def _ensure_tab_started(self, tab: TerminalTabState) -> bool:
        if tab not in self._tabs or self._shutdown_pending:
            return False
        if tab.session is not None:
            return True
        if not self.pluginInstalled:
            message = "请先安装应用内 PowerShell 7 插件。\n"
            if not tab.output.endswith(message):
                self._append_to_tab(tab, message)
            return False
        python_executable = self.python_environment.execution_executable()
        pip_executable = self.python_environment.executable()
        if self._plugin is None:
            shell = Path(os.environ.get("SHELL") or "/bin/zsh")
            arguments = ["-i"]
        else:
            shell = self._plugin.executable
            if not python_executable or not pip_executable:
                message = "Python 环境不可用，请重新启动应用完成初始化。\n"
                if not tab.output.endswith(message):
                    self._append_to_tab(tab, message)
                return False
            arguments = [
                "-NoLogo",
                "-NoProfile",
                "-NoExit",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(resource_path("tools", "powershell-terminal-profile.ps1")),
            ]
        if not python_executable or not pip_executable:
            message = "Python 环境不可用，请重新启动应用完成初始化。\n"
            if not tab.output.endswith(message):
                self._append_to_tab(tab, message)
            return False
        environment = self._terminal_environment()
        environment.update(
            {
                "POPTOOLS_PYTHON": python_executable,
                "POPTOOLS_PIP": pip_executable,
                "PYTHONUTF8": "1",
                "PYTHONIOENCODING": "utf-8",
                "PYTHONUNBUFFERED": "1",
                "TERM": "xterm-256color",
            }
        )

        session = ConPtySession(self)
        tab.output_decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        session.outputReceived.connect(self._on_terminal_output)
        session.processExited.connect(self._on_process_exited)
        session.finished.connect(self._on_session_finished)
        tab.session = session
        tab.intentional_stop = False
        tab.exit_code = 0
        try:
            session.start_process(
                shell,
                arguments,
                self.working_directory,
                environment,
                columns=self._terminal_columns,
                rows=self._terminal_rows,
            )
        except Exception as exc:
            tab.session = None
            session.dispose()
            session.deleteLater()
            self._append_to_tab(tab, f"终端启动失败：{exc}\r\n")
            self.terminalTabsChanged.emit()
            self.runningChanged.emit()
            return False
        self.terminalTabsChanged.emit()
        self.runningChanged.emit()
        return True

    def _terminal_environment(self) -> dict[str, str]:
        environment = self.python_environment.execution_environment()
        adb_executable = bundled_adb_path()
        if adb_executable.is_file():
            environment["POPTOOLS_ADB"] = str(adb_executable)
            environment["PATH"] = os.pathsep.join(
                (str(adb_executable.parent), environment.get("PATH", ""))
            )
        return environment

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
        tab = self._active_tab()
        if tab is None:
            return False
        return self._write_input_to_tab(tab, data)

    @Slot(str, str, result=bool)
    def writeInputToTab(self, tab_id: str, data: str) -> bool:
        tab = self._tab_by_id(tab_id)
        if tab is None:
            return False
        return self._write_input_to_tab(tab, data)

    def _write_input_to_tab(self, tab: TerminalTabState, data: str) -> bool:
        if tab is None or not self._ensure_tab_started(tab) or tab.session is None:
            return False
        return tab.session.write(data.encode("utf-8"))

    @Slot(int, int)
    def resizeTerminal(self, columns: int, rows: int) -> None:
        self._terminal_columns = max(2, columns)
        self._terminal_rows = max(1, rows)
        for tab in self._tabs:
            if tab.session is not None:
                tab.session.resize(self._terminal_columns, self._terminal_rows)

    @Slot()
    def terminalReady(self) -> None:
        self._terminal_ready = True
        for tab in self._tabs:
            self.terminalResetRequested.emit(tab.tab_id)
            if tab.output:
                self.terminalSnapshotData.emit(tab.tab_id, tab.output)
        self.ensureStarted()

    @Slot()
    def terminalDetached(self) -> None:
        self._terminal_ready = False

    @Slot()
    def clear(self) -> None:
        self.writeInput("\x0c")

    @Slot(result=bool)
    def interrupt(self) -> bool:
        """Send Ctrl+C to stop the foreground command without closing the session."""
        return self.writeInput("\x03")

    @Slot()
    def restart(self) -> None:
        tab = self._active_tab()
        if tab is None:
            return
        if tab.session is None:
            self.ensureStarted()
            return
        tab.restart_pending = True
        tab.intentional_stop = True
        tab.session.stop_process()

    @Slot()
    def stop(self) -> None:
        for tab in (*self._tabs, *self._closing_tabs.values()):
            tab.restart_pending = False
            tab.intentional_stop = True
            if tab.session is not None:
                tab.session.stop_process()

    @Slot()
    def shutdown(self) -> None:
        self._shutdown_pending = True
        self.stop()
        tabs = (*self._tabs, *self._closing_tabs.values())
        for tab in tabs:
            session = tab.session
            if session is None:
                continue
            if not session.wait(3_000):
                session.dispose()
                session.wait(2_000)
            if tab.session is session:
                session.dispose()
                tab.session = None
        thread = self._plugin_install_thread
        if thread is not None and thread.isRunning():
            thread.requestInterruption()
            thread.wait()

    @Slot(result=bool)
    def createTerminalTab(self) -> bool:
        if len(self._tabs) >= self.MAX_TERMINAL_TABS:
            return False
        tab = self._create_tab(activate=True)
        if self._terminal_ready:
            self._display_active_tab()
            QTimer.singleShot(0, lambda: self._ensure_tab_started(tab))
        return True

    @Slot(str, result=bool)
    def activateTerminalTab(self, tab_id: str) -> bool:
        tab = self._tab_by_id(tab_id)
        if tab is None:
            return False
        if tab.tab_id == self._active_tab_id:
            return True
        self._active_tab_id = tab.tab_id
        self.terminalTabsChanged.emit()
        self.runningChanged.emit()
        self.outputChanged.emit()
        self._display_active_tab()
        if self._terminal_ready:
            QTimer.singleShot(0, lambda: self._ensure_tab_started(tab))
        return True

    @Slot(str, result=bool)
    def closeTerminalTab(self, tab_id: str) -> bool:
        tab = self._tab_by_id(tab_id)
        if tab is None:
            return False
        index = self._tabs.index(tab)
        was_active = tab.tab_id == self._active_tab_id
        self._tabs.remove(tab)
        if self._terminal_ready:
            self.terminalSessionRemoved.emit(tab.tab_id)
        if tab.session is not None:
            tab.intentional_stop = True
            tab.restart_pending = False
            self._closing_tabs[tab.tab_id] = tab
            tab.session.stop_process()
        if not self._tabs:
            self._create_tab(activate=True, emit=False)
        elif was_active:
            self._active_tab_id = self._tabs[min(index, len(self._tabs) - 1)].tab_id
        self.terminalTabsChanged.emit()
        self.runningChanged.emit()
        self.outputChanged.emit()
        if was_active:
            self._display_active_tab()
            active = self._active_tab()
            if self._terminal_ready and active is not None:
                QTimer.singleShot(0, lambda: self._ensure_tab_started(active))
        return True

    @Slot(bytes)
    def _on_terminal_output(self, payload: bytes) -> None:
        tab = self._tab_for_session(self.sender())
        if tab is not None:
            self._append_to_tab(tab, tab.output_decoder.decode(payload, final=False))

    @Slot(int)
    def _on_process_exited(self, exit_code: int) -> None:
        tab = self._tab_for_session(self.sender())
        if tab is not None:
            tab.exit_code = exit_code

    @Slot()
    def _on_session_finished(self) -> None:
        sender = self.sender()
        if not isinstance(sender, ConPtySession):
            return
        session = sender
        tab = self._tab_for_session(session)
        if tab is None:
            session.dispose()
            session.deleteLater()
            return
        self._append_to_tab(tab, tab.output_decoder.decode(b"", final=True))
        tab_id = tab.tab_id
        tab.session = None
        session.dispose()
        session.deleteLater()
        if tab_id in self._closing_tabs:
            self._closing_tabs.pop(tab_id, None)
            return
        restart_pending = tab.restart_pending
        tab.restart_pending = False
        if not restart_pending and not tab.intentional_stop and not self._shutdown_pending:
            self._append_to_tab(
                tab,
                f"\r\nPowerShell 会话已结束（退出码 {tab.exit_code}）。\r\n",
            )
        tab.intentional_stop = False
        self.terminalTabsChanged.emit()
        if tab.tab_id == self._active_tab_id:
            self.runningChanged.emit()
        if restart_pending and not self._shutdown_pending:
            tab.output = ""
            if tab.tab_id == self._active_tab_id:
                self.terminalResetRequested.emit(tab.tab_id)
                self.outputChanged.emit()
            QTimer.singleShot(0, lambda: self._ensure_tab_started(tab))

    def _append(self, text: str) -> None:
        tab = self._active_tab()
        if tab is not None:
            self._append_to_tab(tab, text)

    def _append_to_tab(self, tab: TerminalTabState, text: str) -> None:
        if not text:
            return
        tab.output = (tab.output + text)[-self.OUTPUT_HISTORY_LIMIT :]
        if self._terminal_ready:
            self.terminalData.emit(tab.tab_id, text)

    def _create_tab(self, *, activate: bool, emit: bool = True) -> TerminalTabState:
        tab_number = self._next_tab_number
        self._next_tab_number += 1
        tab = TerminalTabState(
            tab_id=f"terminal-{tab_number}",
            title=self._terminal_name(),
        )
        self._tabs.append(tab)
        if activate:
            self._active_tab_id = tab.tab_id
        if emit:
            self.terminalTabsChanged.emit()
            self.runningChanged.emit()
            self.outputChanged.emit()
        return tab

    def _active_tab(self) -> TerminalTabState | None:
        return self._tab_by_id(self._active_tab_id)

    def _tab_by_id(self, tab_id: str) -> TerminalTabState | None:
        return next((tab for tab in self._tabs if tab.tab_id == tab_id), None)

    def _tab_for_session(self, session: object) -> TerminalTabState | None:
        return next(
            (tab for tab in (*self._tabs, *self._closing_tabs.values()) if tab.session is session),
            None,
        )

    def _display_active_tab(self) -> None:
        # The native terminal keeps an independent libvterm screen for every
        # tab, so switching tabs only changes the visible session. Replaying a
        # truncated ANSI byte stream here would corrupt terminal state.
        return
