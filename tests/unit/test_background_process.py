from __future__ import annotations

import sys

from poptools.infrastructure.background_process import BackgroundProcess


def test_background_process_captures_stdout_and_stderr_without_console(qtbot) -> None:
    process = BackgroundProcess()
    stdout: list[bytes] = []
    stderr: list[bytes] = []
    process.stdoutReady.connect(stdout.append)
    process.stderrReady.connect(stderr.append)

    with qtbot.waitSignal(process.finished, timeout=5_000) as finished:
        assert process.start(
            sys.executable,
            [
                "-c",
                "import sys; print('stdout-ok'); print('stderr-ok', file=sys.stderr)",
            ],
        )

    assert finished.args == [0]
    assert b"stdout-ok" in b"".join(stdout)
    assert b"stderr-ok" in b"".join(stderr)
    assert process.running is False


def test_background_process_reports_start_failure(tmp_path, qtbot) -> None:
    process = BackgroundProcess()

    with qtbot.waitSignal(process.finished, timeout=1_000) as finished:
        assert process.start(str(tmp_path / "missing.exe"), []) is True

    assert finished.args == [-1]
    assert process.running is False


def test_background_process_reports_started_after_process_is_running(qtbot) -> None:
    process = BackgroundProcess()

    with qtbot.waitSignal(process.started, timeout=1_000):
        assert process.start(sys.executable, ["-c", "pass"]) is True
