from __future__ import annotations

import sys
from pathlib import Path

from poptools.paths import installed_runtime_path


def test_frozen_windows_runtime_is_next_to_executable(
    monkeypatch, tmp_path: Path
) -> None:
    executable = tmp_path / "泡泡工具箱.exe"
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(executable))
    monkeypatch.setattr(sys, "platform", "win32")

    assert installed_runtime_path("python", "python.exe") == (
        tmp_path / "runtime" / "python" / "python.exe"
    )
