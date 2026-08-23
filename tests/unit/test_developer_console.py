import os
import shutil
import sys
import uuid
import weakref
from pathlib import Path
from unittest.mock import patch

import psutil
import pytest
from PySide6.QtCore import QCoreApplication, QEvent

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.conpty import ConPtySession
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


def platform_shell_plugin() -> InstalledPowerShellPlugin | None:
    """Use PowerShell only where it is the application's actual terminal backend."""
    return InstalledPowerShellPlugin() if sys.platform == "win32" else None


def test_developer_console_executes_managed_python_from_embedded_shell(
    tmp_path: Path, qtbot
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    environment = PythonEnvironment(paths, ConfigStore(paths))
    controller = DeveloperConsoleController(
        environment,
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    line_ending = "\r" if sys.platform == "win32" else "\n"

    try:
        assert controller.ensureStarted() is True
        command = "python -c \"print('embedded-result', 40 + 2)\"" + line_ending
        assert controller.writeInput(command) is True

        qtbot.waitUntil(lambda: "embedded-result 42" in controller.output, timeout=5_000)
        assert controller.running is True
        assert "embedded-result 42" in controller.output

        assert controller.writeInput("python -m pip --version" + line_ending) is True
        qtbot.waitUntil(lambda: "site-packages" in controller.output, timeout=5_000)
    finally:
        controller.shutdown()

    qtbot.waitUntil(lambda: not controller.running, timeout=5_000)


def test_developer_console_page_is_wired_to_the_managed_python_controller() -> None:
    project_root = Path(__file__).parents[2]
    main = (project_root / "src" / "poptools" / "ui" / "qml" / "Main.qml").read_text(
        encoding="utf-8"
    )
    page = (
        project_root / "src" / "poptools" / "ui" / "qml" / "components" / "DeveloperConsole.qml"
    ).read_text(encoding="utf-8")
    entrypoint = (project_root / "src" / "poptools" / "main.py").read_text(encoding="utf-8")

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
    assert "terminalBridge.snapshotReceived(data)" in page
    assert "PSReadLine 历史预测" in page
    assert "commandInput" not in page
    assert "recallHistory" not in page
    assert 'text: "执行"' not in page
    assert "root.controller.restart()" in page
    assert "root.controller.terminalTabs" in page
    assert "Layout.maximumHeight: 42" in page
    assert "visible: root.controller.terminalTabs.length > 1" in page
    assert "root.controller.createTerminalTab()" in page
    assert "PrimaryButton {" in page
    assert 'iconName: "add"' in page
    assert "compact: true" in page
    assert "tonal: true" in page
    assert (
        "root.controller.activateTerminalTab(\n"
        "                                    terminalTabDelegate.modelData.tabId)"
    ) in page
    assert (
        "root.controller.closeTerminalTab(\n"
        "                                                terminalTabDelegate.modelData.tabId)"
    ) in page
    assert "最多开启 7 个终端标签" in page
    assert "root.controller.terminalDetached()" in page
    assert 'url: Qt.resolvedUrl("../../terminal/index.html")' in page
    assert 'backgroundColor: "#141A20"' in page
    assert "anchors.margins: 6" in page

    terminal_source = (
        project_root / "src" / "poptools" / "ui" / "terminal" / "terminal-source.js"
    ).read_text(encoding="utf-8")
    terminal_css = (
        project_root / "src" / "poptools" / "ui" / "terminal" / "terminal.css"
    ).read_text(encoding="utf-8")
    assert 'background: "#141a20"' in terminal_source
    assert "replayWritesPending === 0" in terminal_source
    assert "bridge.snapshotReceived.connect" in terminal_source
    assert 'brightBlack: "#9fb3c5"' in terminal_source
    assert "border-radius: 14px" in terminal_css


def test_native_terminal_uses_conpty_and_psreadline() -> None:
    project_root = Path(__file__).parents[2]
    controller = (
        project_root / "src" / "poptools" / "viewmodels" / "developer_console_controller.py"
    ).read_text(encoding="utf-8")
    backend = (project_root / "src" / "poptools" / "infrastructure" / "conpty.py").read_text(
        encoding="utf-8"
    )

    native_backend = (
        project_root / "src" / "poptools" / "infrastructure" / "native_conpty.py"
    ).read_text(encoding="utf-8")
    terminal_profile = (
        project_root
        / "src"
        / "poptools"
        / "resources"
        / "tools"
        / "powershell-terminal-profile.ps1"
    ).read_text(encoding="utf-8")

    assert "NativeConPty(" in backend
    assert "CreatePseudoConsole" in native_backend
    assert "PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE" in native_backend
    assert "blocking=False" in backend
    assert "blocking=True" not in backend
    assert "QProcess" not in controller
    assert "-PredictionSource History" in terminal_profile
    assert "-PredictionViewStyle InlineView" in terminal_profile
    assert '"TERM": "xterm-256color"' in controller
    assert "function global:adb" in terminal_profile
    assert 'environment["POPTOOLS_ADB"]' in controller
    assert '"-File"' in controller
    assert '"-Command"' not in controller
    assert "function global:prompt" not in controller
    assert "OUTPUT_HISTORY_LIMIT = 131_072" in controller
    assert "if self._terminal_ready:" in controller
    assert "PtyProcess" not in backend
    assert "ShowWindow" not in backend
    assert "OpenConsole" not in backend


def test_terminal_prefers_bundled_adb_over_system_shims(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    adb = tmp_path / "runtime" / "platform-tools" / "adb.exe"
    adb.parent.mkdir(parents=True)
    adb.touch()
    monkeypatch.setattr(
        "poptools.viewmodels.developer_console_controller.bundled_adb_path",
        lambda: adb,
    )
    monkeypatch.setenv("PATH", r"C:\Users\test\scoop\shims;C:\Windows")
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=None,
    )

    environment = controller._terminal_environment()  # noqa: SLF001

    assert environment["POPTOOLS_ADB"] == str(adb)
    assert environment["PATH"].split(os.pathsep)[0] == str(adb.parent)


def test_windows_status_code_is_normalized_for_qt_signal() -> None:
    with patch("poptools.infrastructure.conpty.os.name", "nt"):
        assert ConPtySession._normalize_exit_code(0xC000013A) == -1073741510
        assert ConPtySession._normalize_exit_code(0) == 0


def test_windows_bundle_uses_system_conpty_without_helper_executables() -> None:
    spec = (Path(__file__).parents[2] / "packaging" / "poptools.spec").read_text(encoding="utf-8")

    assert '"OpenConsole.exe"' not in spec
    assert '"winpty-agent.exe"' not in spec
    assert 'collect_submodules("winpty")' not in spec
    assert "binaries=platform_binaries" in spec


def test_terminal_output_history_is_bounded_and_only_streamed_when_attached(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
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


def test_switching_tabs_replays_history_without_using_live_terminal_data(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    snapshots: list[str] = []
    live_data: list[str] = []
    controller.terminalSnapshotData.connect(snapshots.append)
    controller.terminalData.connect(live_data.append)
    first_tab_id = str(controller.terminalTabs[0]["tabId"])
    controller._terminal_ready = True  # noqa: SLF001
    controller._append("saved-control-sequence")  # noqa: SLF001

    controller._terminal_ready = False  # noqa: SLF001
    controller.createTerminalTab()
    controller._active_tab_id = first_tab_id  # noqa: SLF001
    controller._terminal_ready = True  # noqa: SLF001
    controller._display_active_tab()  # noqa: SLF001

    assert snapshots == ["saved-control-sequence"]
    assert live_data == ["saved-control-sequence"]


def test_terminal_tabs_are_independent_and_limited_to_seven(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )

    first_tab_id = str(controller.terminalTabs[0]["tabId"])
    assert controller.terminalTabs[0]["title"] == controller.terminalName
    controller._append("first-output")
    for _ in range(6):
        assert controller.createTerminalTab() is True

    assert len(controller.terminalTabs) == 7
    assert {tab["title"] for tab in controller.terminalTabs} == {controller.terminalName}
    assert controller.canCreateTerminalTab is False
    assert controller.createTerminalTab() is False
    assert controller.output == ""

    assert controller.activateTerminalTab(first_tab_id) is True
    assert controller.output == "first-output"
    assert controller.closeTerminalTab(first_tab_id) is True
    assert len(controller.terminalTabs) == 6
    assert controller.canCreateTerminalTab is True


def test_closing_last_terminal_tab_immediately_creates_a_replacement(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    original_id = str(controller.terminalTabs[0]["tabId"])

    assert controller.closeTerminalTab(original_id) is True

    assert len(controller.terminalTabs) == 1
    assert controller.terminalTabs[0]["tabId"] != original_id


def test_two_terminal_tabs_run_independent_shell_sessions(tmp_path: Path, qtbot) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    line_ending = "\r" if sys.platform == "win32" else "\n"
    first_tab_id = str(controller.terminalTabs[0]["tabId"])
    first_marker = f"first-{uuid.uuid4().hex}"
    second_marker = f"second-{uuid.uuid4().hex}"

    def marker_command(marker: str) -> str:
        midpoint = len(marker) // 2
        return f"python -c \"print('{marker[:midpoint]}' + '{marker[midpoint:]}')\"" + line_ending

    try:
        assert controller.ensureStarted() is True
        first_tab = controller._active_tab()  # noqa: SLF001
        assert first_tab is not None and first_tab.session is not None

        assert controller.createTerminalTab() is True
        second_tab_id = str(controller.terminalTabs[-1]["tabId"])
        assert controller.ensureStarted() is True
        second_tab = controller._active_tab()  # noqa: SLF001
        assert second_tab is not None and second_tab.session is not None
        assert second_tab.session is not first_tab.session

        assert controller.writeInput(marker_command(second_marker))
        qtbot.waitUntil(lambda: second_marker in controller.output, timeout=5_000)

        assert controller.activateTerminalTab(first_tab_id) is True
        assert controller.writeInput(marker_command(first_marker))
        qtbot.waitUntil(lambda: first_marker in controller.output, timeout=5_000)

        assert second_marker not in controller.output
        assert controller.activateTerminalTab(second_tab_id) is True
        assert second_marker in controller.output
        assert first_marker not in controller.output
    finally:
        controller.shutdown()


def test_repeated_terminal_sessions_release_qthreads_and_children(tmp_path: Path, qtbot) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    sessions: list[weakref.ReferenceType[object]] = []
    current_process = psutil.Process()
    existing_children = {child.pid for child in current_process.children(recursive=True)}

    try:
        for _ in range(6):
            assert controller.ensureStarted() is True
            active_tab = controller._active_tab()  # noqa: SLF001
            assert active_tab is not None and active_tab.session is not None
            sessions.append(weakref.ref(active_tab.session))
            controller.stop()
            qtbot.waitUntil(lambda: not controller.running, timeout=5_000)
            QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    finally:
        controller.shutdown()

    assert all(reference() is None for reference in sessions)
    assert controller.children() == []
    remaining_children = {child.pid for child in current_process.children(recursive=True)}
    assert remaining_children - existing_children == set()


@pytest.mark.skipif(sys.platform != "win32", reason="ConPTY is Windows-only")
def test_restart_uses_system_conpty_without_openconsole_helper(tmp_path: Path, qtbot) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )
    current_process = psutil.Process()

    def openconsole_children() -> list[psutil.Process]:
        return [
            child
            for child in current_process.children(recursive=True)
            if child.name().casefold() == "openconsole.exe"
        ]

    try:
        assert controller.ensureStarted() is True
        first_tab = controller._active_tab()  # noqa: SLF001
        assert first_tab is not None and first_tab.session is not None
        first_session = first_tab.session
        assert openconsole_children() == []

        controller.restart()
        qtbot.waitUntil(
            lambda: (
                controller._active_tab() is not None  # noqa: SLF001
                and controller._active_tab().session is not None  # noqa: SLF001
                and controller._active_tab().session is not first_session  # noqa: SLF001
                and controller.running
            ),
            timeout=5_000,
        )

        assert openconsole_children() == []
    finally:
        controller.shutdown()


@pytest.mark.skipif(sys.platform != "win32", reason="PowerShell history is Windows-only")
def test_restart_does_not_add_terminal_bootstrap_to_powershell_history(
    tmp_path: Path, qtbot
) -> None:
    paths = AppPaths(tmp_path)
    paths.ensure()
    controller = DeveloperConsoleController(
        PythonEnvironment(paths, ConfigStore(paths)),
        tmp_path,
        powershell_plugin=platform_shell_plugin(),  # type: ignore[arg-type]
    )

    try:
        assert controller.ensureStarted() is True
        first_tab = controller._active_tab()  # noqa: SLF001
        assert first_tab is not None and first_tab.session is not None
        first_session = first_tab.session

        controller.restart()
        qtbot.waitUntil(
            lambda: (
                controller._active_tab() is not None  # noqa: SLF001
                and controller._active_tab().session is not None  # noqa: SLF001
                and controller._active_tab().session is not first_session  # noqa: SLF001
                and controller.running
            ),
            timeout=5_000,
        )
        assert controller.writeInput("history; Write-Output '__HISTORY_DONE__'\r") is True
        qtbot.waitUntil(lambda: controller.output.count("__HISTORY_DONE__") >= 2, timeout=5_000)

        assert "$OutputEncoding" not in controller.output
        assert "Set-PSReadLineOption" not in controller.output
    finally:
        controller.shutdown()


def test_idle_terminal_read_errors_do_not_end_a_live_session() -> None:
    backend_path = Path(__file__).parents[2] / "src" / "poptools" / "infrastructure" / "conpty.py"
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
    assert "if restart_pending and not self._shutdown_pending:" in source


@pytest.mark.skipif(sys.platform != "win32", reason="PowerShell plugin is Windows-only")
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
