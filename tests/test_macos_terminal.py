from __future__ import annotations

import sys
from pathlib import Path

import pytest

from poptools.infrastructure import macos_terminal
from poptools.infrastructure.macos_terminal import MacOSTerminalLauncher


class FakeProcess:
    pass


def _sample_environment() -> dict[str, str]:
    return {
        "PATH": "/managed/python/bin:/managed/android:/usr/bin",
        "VIRTUAL_ENV": "/managed/python",
        "POPTOOLS_PYTHON": "/managed/runtime/bin/python",
        "POPTOOLS_PIP": "/managed/python/bin/python",
        "POPTOOLS_ADB": "/managed/android/adb",
        "POPTOOLS_SCRCPY": "/managed/android/scrcpy",
        "IGNORED_SECRET": "must-not-be-exported",
    }


def test_startup_script_exports_managed_environment(tmp_path: Path) -> None:
    working_directory = tmp_path / "working directory"
    working_directory.mkdir()
    script = tmp_path / "runtime dir" / "terminal" / "poptools-test.command"

    contents = MacOSTerminalLauncher._startup_script(
        script,
        working_directory,
        _sample_environment(),
    )

    assert "export VIRTUAL_ENV=/managed/python" in contents
    assert "export POPTOOLS_ADB=/managed/android/adb" in contents
    assert "export POPTOOLS_SCRCPY=/managed/android/scrcpy" in contents
    assert "must-not-be-exported" not in contents
    assert f"cd -- '{working_directory}'" in contents
    assert f"rm -f -- '{script}'" in contents
    assert 'exec "${SHELL:-/bin/zsh}" -i' in contents


@pytest.mark.skipif(sys.platform != "darwin", reason="requires macOS Terminal.app")
def test_launcher_opens_terminal_with_temporary_environment(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    calls: list[tuple[list[str], dict[str, object]]] = []

    open_command = Path("/usr/bin/open")
    monkeypatch.setattr(macos_terminal.shutil, "which", lambda _name: str(open_command))
    monkeypatch.setattr(
        macos_terminal.subprocess,
        "Popen",
        lambda arguments, **kwargs: calls.append((arguments, kwargs)) or FakeProcess(),
    )
    working_directory = tmp_path / "working directory"
    working_directory.mkdir()
    launcher = MacOSTerminalLauncher(tmp_path / "runtime")

    script = launcher.open(working_directory, _sample_environment())

    assert calls[0][0] == ["/usr/bin/open", "-a", "Terminal", str(script)]
    assert script.stat().st_mode & 0o777 == 0o700


def test_launcher_rejects_non_macos(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(macos_terminal.sys, "platform", "linux")

    with pytest.raises(RuntimeError, match="仅适用于 macOS"):
        MacOSTerminalLauncher(tmp_path).open(tmp_path, {})
