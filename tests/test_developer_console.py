from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace

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

    def resize(self, columns: int, rows: int) -> None:
        self.sizes.append((columns, rows))


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
