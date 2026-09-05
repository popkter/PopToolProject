from __future__ import annotations

from pathlib import Path

import pytest

from poptools.infrastructure import macos_terminal
from poptools.infrastructure.macos_terminal import MacOSTerminalLauncher


class FakeProcess:
    pass


def test_launcher_opens_terminal_with_temporary_environment(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    calls: list[tuple[list[str], dict[str, object]]] = []

    monkeypatch.setattr(macos_terminal.sys, "platform", "darwin")
    monkeypatch.setattr(macos_terminal.shutil, "which", lambda _name: "/usr/bin/open")
    monkeypatch.setattr(
        macos_terminal.subprocess,
        "Popen",
        lambda arguments, **kwargs: calls.append((arguments, kwargs)) or FakeProcess(),
    )
    working_directory = tmp_path / "working directory"
    working_directory.mkdir()
    launcher = MacOSTerminalLauncher(tmp_path / "runtime")

    script = launcher.open(
        working_directory,
        {
            "PATH": "/managed/python/bin:/managed/android:/usr/bin",
            "VIRTUAL_ENV": "/managed/python",
            "POPTOOLS_PYTHON": "/managed/runtime/bin/python",
            "POPTOOLS_PIP": "/managed/python/bin/python",
            "POPTOOLS_ADB": "/managed/android/adb",
            "POPTOOLS_SCRCPY": "/managed/android/scrcpy",
            "IGNORED_SECRET": "must-not-be-exported",
        },
    )

    contents = script.read_text(encoding="utf-8")
    assert calls[0][0] == ["/usr/bin/open", "-a", "Terminal", str(script)]
    assert "export VIRTUAL_ENV=/managed/python" in contents
    assert "export POPTOOLS_ADB=/managed/android/adb" in contents
    assert "export POPTOOLS_SCRCPY=/managed/android/scrcpy" in contents
    assert "must-not-be-exported" not in contents
    assert f"cd -- '{working_directory}'" in contents
    assert 'exec "${SHELL:-/bin/zsh}" -i' in contents
    assert script.stat().st_mode & 0o777 == 0o700


def test_launcher_rejects_non_macos(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(macos_terminal.sys, "platform", "linux")

    with pytest.raises(RuntimeError, match="仅适用于 macOS"):
        MacOSTerminalLauncher(tmp_path).open(tmp_path, {})
