from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from PySide6.QtCore import QUrl

from poptools.viewmodels.developer_console_controller import DeveloperConsoleController


class FakePythonEnvironment:
    def __init__(self, root: Path) -> None:
        self.paths = SimpleNamespace(python_venv_dir=root / "python", data_dir=root)

    def execution_executable(self) -> str:
        return str(self.paths.python_venv_dir / "python.exe")

    def executable(self) -> str:
        return str(self.paths.python_venv_dir / "pip.exe")

    def execution_environment(self) -> dict[str, str]:
        return {}


class FakePowerShellPlugin:
    package = SimpleNamespace(version="7.6.0")

    def __init__(self, root: Path) -> None:
        self.install_directory = root / "powershell"
        self.executable = self.install_directory / "pwsh.exe"

    def is_installed(self) -> bool:
        return True


class FakeSession:
    def __init__(self) -> None:
        self.sizes: list[tuple[int, int]] = []
        self.writes: list[bytes] = []

    def resize(self, columns: int, rows: int) -> None:
        self.sizes.append((columns, rows))

    def write(self, payload: bytes) -> bool:
        self.writes.append(payload)
        return True


class FakeStartedSession:
    last_start: tuple[Path, list[str], Path, dict[str, str], int, int] | None = None

    def __init__(self, _parent: object = None) -> None:
        self.outputReceived = SimpleNamespace(connect=lambda _callback: None)
        self.processExited = SimpleNamespace(connect=lambda _callback: None)
        self.finished = SimpleNamespace(connect=lambda _callback: None)

    def start_process(
        self,
        shell: Path,
        arguments: list[str],
        working_directory: Path,
        environment: dict[str, str],
        *,
        columns: int,
        rows: int,
    ) -> None:
        type(self).last_start = (
            shell, arguments, working_directory, environment, columns, rows
        )


def make_controller(tmp_path: Path) -> DeveloperConsoleController:
    environment = FakePythonEnvironment(tmp_path)
    plugin = FakePowerShellPlugin(tmp_path)
    return DeveloperConsoleController(
        environment,  # type: ignore[arg-type]
        tmp_path,
        plugin,  # type: ignore[arg-type]
    )


def test_terminal_output_is_routed_to_its_own_native_session(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    routed: list[tuple[str, str]] = []
    controller.terminalData.connect(lambda tab_id, text: routed.append((tab_id, text)))
    controller._terminal_ready = True

    first = controller._tabs[0]
    controller._append_to_tab(first, "first")
    assert controller.createTerminalTab()
    second = controller._tabs[1]
    controller._append_to_tab(second, "second")

    assert routed == [(first.tab_id, "first"), (second.tab_id, "second")]


def test_switching_tabs_does_not_replay_truncated_ansi_history(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    resets: list[str] = []
    snapshots: list[tuple[str, str]] = []
    controller.terminalResetRequested.connect(resets.append)
    controller.terminalSnapshotData.connect(
        lambda tab_id, text: snapshots.append((tab_id, text))
    )
    controller._terminal_ready = True

    first = controller._tabs[0]
    first.output = "\x1b[31mred"
    assert controller.createTerminalTab()
    second = controller._tabs[1]
    assert controller.activateTerminalTab(first.tab_id)
    assert controller.activateTerminalTab(second.tab_id)

    assert resets == []
    assert snapshots == []


def test_resize_updates_every_running_terminal_tab(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    assert controller.createTerminalTab()
    sessions = [FakeSession(), FakeSession()]
    for tab, session in zip(controller._tabs, sessions, strict=True):
        tab.session = session  # type: ignore[assignment]

    controller.resizeTerminal(132, 42)

    assert [session.sizes for session in sessions] == [[(132, 42)], [(132, 42)]]


def test_closing_tab_removes_native_terminal_session(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    removed: list[str] = []
    controller.terminalSessionRemoved.connect(removed.append)
    controller._terminal_ready = True
    tab_id = controller._active_tab_id

    assert controller.closeTerminalTab(tab_id)

    assert removed == [tab_id]


def test_interrupt_sends_ctrl_c_to_active_terminal_without_stopping_session(
    tmp_path: Path,
) -> None:
    controller = make_controller(tmp_path)
    session = FakeSession()
    controller._tabs[0].session = session  # type: ignore[assignment]

    assert controller.interrupt()

    assert session.writes == [b"\x03"]
    assert controller._tabs[0].session is session


def test_embedded_powershell_loads_user_profile(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    FakeStartedSession.last_start = None

    with patch(
        "poptools.viewmodels.developer_console_controller.ConPtySession",
        FakeStartedSession,
    ):
        assert controller.ensureStarted()

    assert FakeStartedSession.last_start is not None
    arguments = FakeStartedSession.last_start[1]
    assert "-NoProfile" not in arguments
    assert arguments[:2] == ["-NoLogo", "-NoExit"]
    assert arguments[-2] == "-File"
    assert arguments[-1].endswith("powershell-terminal-profile.ps1")


def test_terminal_defaults_to_user_home_directory(tmp_path: Path) -> None:
    environment = FakePythonEnvironment(tmp_path)
    plugin = FakePowerShellPlugin(tmp_path)
    controller = DeveloperConsoleController(
        environment,  # type: ignore[arg-type]
        powershell_plugin=plugin,  # type: ignore[arg-type]
    )
    FakeStartedSession.last_start = None

    with patch(
        "poptools.viewmodels.developer_console_controller.ConPtySession",
        FakeStartedSession,
    ):
        assert controller.ensureStarted()

    assert FakeStartedSession.last_start is not None
    assert FakeStartedSession.last_start[2] == Path.home()


def test_dropped_paths_are_quoted_as_powershell_arguments(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    plain = QUrl.fromLocalFile(str(tmp_path / "plain.txt"))
    spaced = QUrl.fromLocalFile(str(tmp_path / "folder name" / "a'b.txt"))

    result = controller.formatDroppedPaths(
        [plain, "https://example.com/ignored.txt", spaced]
    )

    assert result == (
        f" '{plain.toLocalFile()}' "
        f"'{spaced.toLocalFile().replace(chr(39), chr(39) * 2)}'"
    )
    assert "\r" not in result
    assert "\n" not in result


def test_custom_terminal_title_overrides_shell_title_until_reset(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    tab_id = controller.activeTerminalTabId

    assert controller.updateTerminalTitle(tab_id, "project shell")
    assert controller.terminalTabs[0]["title"] == "project shell"
    assert controller.renameTerminalTab(tab_id, "  build logs  ")
    assert controller.terminalTabs[0]["title"] == "build logs"
    assert controller.terminalTabs[0]["hasCustomTitle"] is True

    assert controller.updateTerminalTitle(tab_id, "changed by shell")
    assert controller.terminalTabs[0]["title"] == "build logs"
    assert controller.resetTerminalTabTitle(tab_id)
    assert controller.terminalTabs[0]["title"] == "changed by shell"
    assert controller.terminalTabs[0]["hasCustomTitle"] is False


def test_relative_terminal_tab_switching_wraps_at_both_ends(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    first_id = controller.activeTerminalTabId
    assert controller.createTerminalTab()
    second_id = controller.activeTerminalTabId
    assert controller.createTerminalTab()
    third_id = controller.activeTerminalTabId

    assert controller.activateRelativeTerminalTab(1)
    assert controller.activeTerminalTabId == first_id
    assert controller.activateRelativeTerminalTab(-1)
    assert controller.activeTerminalTabId == third_id
    assert controller.activateTerminalTab(first_id)
    assert controller.activateRelativeTerminalTab(1)
    assert controller.activeTerminalTabId == second_id


def test_bulk_terminal_tab_close_operations_keep_requested_tab(tmp_path: Path) -> None:
    controller = make_controller(tmp_path)
    first_id = controller.activeTerminalTabId
    assert controller.createTerminalTab()
    second_id = controller.activeTerminalTabId
    assert controller.createTerminalTab()
    third_id = controller.activeTerminalTabId

    assert controller.closeTerminalTabsToRight(second_id)
    assert [tab["tabId"] for tab in controller.terminalTabs] == [first_id, second_id]

    assert controller.createTerminalTab()
    assert controller.closeOtherTerminalTabs(second_id)
    assert [tab["tabId"] for tab in controller.terminalTabs] == [second_id]
    assert controller.activeTerminalTabId == second_id
    assert controller._tab_by_id(third_id) is None
