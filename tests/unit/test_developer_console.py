import shutil
import weakref
from pathlib import Path

import psutil
import pytest
from PySide6.QtCore import QCoreApplication, QEvent

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.paths import AppPaths
from poptools.viewmodels.developer_console_controller import DeveloperConsoleController


class InstalledPowerShellPlugin:
    def __init__(self) -> None:
        executable = shutil.which("pwsh")
        if not executable:
            pytest.skip("PowerShell 7 is required for the interactive console test")
        self.executable = Path(executable)
        self.install_directory = self.executable.parent

        class Package:
            version = "test"

        self.package = Package()

    def is_installed(self) -> bool:
        return True


def test_developer_console_executes_managed_python_from_embedded_shell(
    tmp_path: Path, qtbot
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    environment = PythonEnvironment(paths, ConfigStore(paths))
    controller = DeveloperConsoleController(
        environment,
        tmp_path,
        powershell_plugin=InstalledPowerShellPlugin(),  # type: ignore[arg-type]
    )

    assert controller.ensureStarted() is True
    assert controller.writeInput('python -c "print(\'embedded-result\', 40 + 2)"\r') is True

    qtbot.waitUntil(lambda: "embedded-result 42" in controller.output, timeout=5_000)
    assert controller.running is True
    assert "embedded-result 42" in controller.output

    assert controller.writeInput("pip --version\r") is True
    qtbot.waitUntil(lambda: "site-packages" in controller.output, timeout=5_000)

    controller.stop()
    qtbot.waitUntil(lambda: not controller.running, timeout=5_000)


def test_developer_console_page_is_wired_to_the_managed_python_controller() -> None:
    project_root = Path(__file__).parents[2]
    main = (project_root / "src" / "poptools" / "ui" / "qml" / "Main.qml").read_text(
        encoding="utf-8"
    )
    page = (
        project_root
        / "src"
        / "poptools"
        / "ui"
        / "qml"
        / "components"
        / "DeveloperConsole.qml"
    ).read_text(encoding="utf-8")
    entrypoint = (project_root / "src" / "poptools" / "main.py").read_text(
        encoding="utf-8"
    )

    assert 'label: "终端"' in main
    assert 'iconName: "terminal"' in main
    assert "DeveloperConsole {" in main
    assert "visible: window.developerSelected" in main
    assert "developerConsoleController.deactivate()" not in main
    assert "controller: developerConsoleController" in main
    assert "developerConsoleController.requestTerminalAccess()" in main
    assert "settingsController.terminalEnabled" in main
    assert "visible: settingsController.terminalEnabled" in main
    assert "settingsController.saveTerminalEnabled(true)" in main
    assert "developerConsoleController.stop()" in main
    assert "PowerShellPluginDialog {" in main
    assert "app.aboutToQuit.connect(developer_console_controller.shutdown)" in entrypoint
    plugin_dialog = (
        project_root
        / "src"
        / "poptools"
        / "ui"
        / "qml"
        / "components"
        / "PowerShellPluginDialog.qml"
    ).read_text(encoding="utf-8")
    assert "controller.installPowerShellPlugin()" in plugin_dialog
    assert "controller.cancelPowerShellPluginInstall()" in plugin_dialog
    assert "id: dialogFooter" in plugin_dialog
    assert "Dialog {" in plugin_dialog
    assert "anchors.centerIn: Overlay.overlay" in plugin_dialog
    assert "modal: true" in plugin_dialog
    assert "Layout.preferredHeight: 92" in plugin_dialog
    assert 'text: "安装 PowerShell 7 插件"' in plugin_dialog
    assert 'text: "为内置终端安装应用专用的 PowerShell 运行环境"' in plugin_dialog
    assert "radius: 22" in plugin_dialog
    assert "? Popup.NoAutoClose : Popup.CloseOnEscape" in plugin_dialog
    assert 'text: root.controller.pluginInstalling ? "取消安装" : "取消"' in plugin_dialog
    assert "enabled: !root.controller.pluginInstalling" in plugin_dialog
    assert "Window {" not in plugin_dialog
    assert "Popup.Window" not in plugin_dialog
    assert '"developerConsoleController", developer_console_controller' in entrypoint
    assert "WebEngineView" in page
    assert "WebChannel" in page
    assert "root.controller.writeInput(data)" in page
    assert "PSReadLine 历史预测" in page
    assert "commandInput" not in page
    assert "recallHistory" not in page
    assert 'text: "执行"' not in page
    assert "root.controller.restart()" in page
    assert "root.controller.terminalDetached()" in page
    assert 'url: Qt.resolvedUrl("../../terminal/index.html")' in page
    assert 'backgroundColor: "#141A20"' in page
    assert 'anchors.margins: 6' in page

    terminal_source = (
        project_root / "src" / "poptools" / "ui" / "terminal" / "terminal-source.js"
    ).read_text(encoding="utf-8")
    terminal_css = (
        project_root / "src" / "poptools" / "ui" / "terminal" / "terminal.css"
    ).read_text(encoding="utf-8")
    assert 'background: "#141a20"' in terminal_source
    assert 'brightBlack: "#9fb3c5"' in terminal_source
    assert "border-radius: 14px" in terminal_css


def test_native_terminal_uses_conpty_and_psreadline() -> None:
    project_root = Path(__file__).parents[2]
    controller = (
        project_root / "src" / "poptools" / "viewmodels" / "developer_console_controller.py"
    ).read_text(encoding="utf-8")
    backend = (
        project_root / "src" / "poptools" / "infrastructure" / "conpty.py"
    ).read_text(encoding="utf-8")

    assert "Backend.ConPTY" in backend
    assert "PTY(" in backend
    assert "blocking=False" in backend
    assert "blocking=True" not in backend
    assert "QProcess" not in controller
    assert "-PredictionSource History" in controller
    assert "-PredictionViewStyle InlineView" in controller
    assert '"TERM": "xterm-256color"' in controller
    assert "function global:prompt" not in controller
    assert "OUTPUT_HISTORY_LIMIT = 131_072" in controller
    assert "if self._terminal_ready:" in controller
    assert "PtyProcess" not in backend
    assert "_terminate_console_hosts" in backend
    assert 'process.name().casefold() == "openconsole.exe"' in backend


def test_terminal_output_history_is_bounded_and_only_streamed_when_attached(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=InstalledPowerShellPlugin(),  # type: ignore[arg-type]
    )
    streamed: list[str] = []
    controller.terminalData.connect(streamed.append)

    changed: list[bool] = []
    controller.outputChanged.connect(lambda: changed.append(True))
    controller._append("a" * (controller.OUTPUT_HISTORY_LIMIT + 2048))
    assert len(controller.output) == controller.OUTPUT_HISTORY_LIMIT
    assert streamed == []
    assert changed == []

    controller._terminal_ready = True
    controller._append("visible")
    assert streamed == ["visible"]


def test_repeated_terminal_sessions_release_qthreads_and_children(
    tmp_path: Path, qtbot
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=InstalledPowerShellPlugin(),  # type: ignore[arg-type]
    )
    sessions: list[weakref.ReferenceType[object]] = []
    current_process = psutil.Process()
    existing_children = {child.pid for child in current_process.children(recursive=True)}

    for _ in range(6):
        assert controller.ensureStarted() is True
        assert controller._session is not None
        sessions.append(weakref.ref(controller._session))
        controller.stop()
        qtbot.waitUntil(lambda: not controller.running, timeout=5_000)
        QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)

    assert all(reference() is None for reference in sessions)
    assert controller.children() == []
    remaining_children = {child.pid for child in current_process.children(recursive=True)}
    assert remaining_children - existing_children == set()


def test_idle_terminal_read_errors_do_not_end_a_live_session() -> None:
    backend_path = (
        Path(__file__).parents[2]
        / "src"
        / "poptools"
        / "infrastructure"
        / "conpty.py"
    )
    backend = backend_path.read_text(encoding="utf-8")

    assert "if not pty.isalive():" in backend
    assert "self.msleep(16)" in backend
    assert "blocking=True" not in backend


def test_unexpected_terminal_exit_does_not_auto_restart() -> None:
    controller_path = (
        Path(__file__).parents[2]
        / "src"
        / "poptools"
        / "viewmodels"
        / "developer_console_controller.py"
    )
    source = controller_path.read_text(encoding="utf-8")

    assert "elif self._terminal_ready:" not in source
    assert "if not self._restart_pending and not self._shutdown_pending:" in source


def test_developer_console_requires_the_application_powershell_plugin(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    environment = PythonEnvironment(paths, ConfigStore(paths))
    controller = DeveloperConsoleController(environment, tmp_path)

    requested: list[tuple[str, str]] = []
    controller.pluginInstallPromptRequested.connect(
        lambda version, directory: requested.append((version, directory))
    )

    assert controller.requestTerminalAccess() is False
    assert requested == [(controller.pluginVersion, controller.pluginDirectory)]
    assert controller.ensureStarted() is False
    assert "请先安装应用内 PowerShell 7 插件" in controller.output


def test_powershell_plugin_install_can_only_be_cancelled_explicitly(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
    )

    class FakeInstallThread:
        interrupted = False

        def requestInterruption(self) -> None:
            self.interrupted = True

    thread = FakeInstallThread()
    controller._plugin_install_thread = thread  # type: ignore[assignment]  # noqa: SLF001
    changes: list[bool] = []
    controller.pluginStateChanged.connect(lambda: changes.append(True))

    assert controller.cancelPowerShellPluginInstall() is True
    assert thread.interrupted is True
    assert controller.pluginInstallStatus == "正在取消 PowerShell 7 插件安装…"
    assert changes == [True]
