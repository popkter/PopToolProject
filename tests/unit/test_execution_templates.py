import os
import sys
from pathlib import Path

import pytest

from poptools.domain.models import (
    ExecutorDefinition,
    ExecutorKind,
    ParameterDefinition,
    ParameterKind,
    ToolDefinition,
    ToolSection,
)
from poptools.paths import AppPaths, resource_path
from poptools.runners.execution_manager import ExecutionManager


def test_conditional_arguments(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    result = manager._render_args(  # noqa: SLF001
        ["?device:-s", "?device:${device}", "shell", "?doa:--ei", "?doa:${doa}"],
        {"device": "ABC", "doa": ""},
    )
    assert result == ["-s", "ABC", "shell"]


def test_powershell_command_template_is_rendered(tmp_path: Path, monkeypatch) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    monkeypatch.setattr(
        "poptools.runners.execution_manager.shutil.which",
        lambda name: "powershell.exe" if name == "powershell" else None,
    )
    tool = ToolDefinition(
        id="custom.test",
        section=ToolSection.CUSTOM,
        title="动态命令",
        executor=ExecutorDefinition(
            kind=ExecutorKind.POWERSHELL,
            command="adb shell ${输入密码}",
        ),
    )

    launch = manager._build_launch(tool, {"输入密码": "adbd1234"})  # noqa: SLF001

    assert launch == (
        "powershell.exe",
        [
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "$OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
            "adb shell adbd1234",
        ],
    )


def test_declared_parameter_line_is_not_executed(tmp_path: Path, monkeypatch) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    monkeypatch.setattr(
        "poptools.runners.execution_manager.shutil.which",
        lambda name: "powershell.exe" if name == "powershell" else None,
    )
    tool = ToolDefinition(
        id="custom.declared-parameter",
        section=ToolSection.CUSTOM,
        title="复用变量",
        executor=ExecutorDefinition(
            kind=ExecutorKind.POWERSHELL,
            command=(
                "pVal value1: ${车辆识别码=VIN123}\n"
                "adb shell setprop persist.sys.vin ${value1}\n"
                "adb shell setprop persist.sys.ihuid ${value1}"
            ),
        ),
    )

    launch = manager._build_launch(tool, {"value1": "VIN999"})  # noqa: SLF001

    assert launch == (
        "powershell.exe",
        [
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "$OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
            "adb shell setprop persist.sys.vin VIN999\n"
            "adb shell setprop persist.sys.ihuid VIN999",
        ],
    )


def test_process_command_can_keep_all_arguments_in_script_content(
    tmp_path: Path, monkeypatch
) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    monkeypatch.setattr(manager, "_resolve_program", lambda _command: "adb.exe")
    tool = ToolDefinition(
        id="local.inline-process",
        section=ToolSection.CUSTOM,
        title="完整进程命令",
        executor=ExecutorDefinition(
            kind=ExecutorKind.PROCESS,
            command="adb ?device:-s ?device:${device} shell am start",
        ),
    )

    launch = manager._build_launch(tool, {"device": "emulator-5554"})  # noqa: SLF001

    assert launch == ("adb.exe", ["-s", "emulator-5554", "shell", "am", "start"])


def test_batch_kind_executes_the_script_editor_content(tmp_path: Path, monkeypatch) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    monkeypatch.setattr(
        "poptools.runners.execution_manager.shutil.which",
        lambda name: "cmd.exe" if name == "cmd" else None,
    )
    tool = ToolDefinition(
        id="custom.batch",
        section=ToolSection.CUSTOM,
        title="BAT 脚本",
        executor=ExecutorDefinition(
            kind=ExecutorKind.BATCH,
            command="echo first\r\necho second",
        ),
    )

    output_dir = tmp_path / "run"
    launch = manager._build_launch(tool, {}, output_dir)  # noqa: SLF001

    script = output_dir / "command.bat"
    assert launch == ("cmd.exe", ["/d", "/q", "/c", str(script)])
    assert script.read_bytes() == b"echo first\r\necho second"


@pytest.mark.skipif(sys.platform != "win32", reason="BAT execution requires Windows cmd.exe")
def test_batch_script_runs_all_lines_with_bundled_adb_and_does_not_wait_at_pause(
    tmp_path: Path, qtbot, monkeypatch
) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    fake_adb = tmp_path / "platform-tools" / "adb.bat"
    fake_adb.parent.mkdir(parents=True)
    fake_adb.write_text(
        "@echo off\necho package:fake.apk\necho versionName=1.2.3\n",
        encoding="utf-8",
        newline="\r\n",
    )
    monkeypatch.setattr(
        manager,
        "_resolve_program",
        lambda command: str(fake_adb) if command == "adb" else None,
    )
    messages: list[str] = []
    manager.output.connect(messages.append)
    tool = ToolDefinition(
        id="custom.batch.integration",
        section=ToolSection.CUSTOM,
        title="BAT integration",
        executor=ExecutorDefinition(
            kind=ExecutorKind.BATCH,
            command=(
                "chcp 65001>nul\n"
                "echo daemon:\n"
                "adb shell pm path com.zeekr.speech.daemon\n"
                "adb shell dumpsys package com.zeekr.speech.daemon | findstr versionName\n"
                "pause"
            ),
        ),
    )

    with qtbot.waitSignal(manager.finished, timeout=3_000) as finished:
        assert manager.start(tool, {}) is True

    output = "".join(messages)
    assert finished.args == [0]
    assert "daemon:" in output
    assert "package:fake.apk" in output
    assert "versionName=1.2.3" in output
    assert "echo daemon:" not in output
    assert "cmd.exe" not in output.lower()
    assert "command.bat" not in output.lower()
    assert manager.running is False


def test_python_kind_executes_a_script_directly(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    script = tmp_path / "example.py"
    script.write_text("print('ok')", encoding="utf-8")
    tool = ToolDefinition(
        id="custom.python",
        section=ToolSection.CUSTOM,
        title="Python script",
        executor=ExecutorDefinition(
            kind=ExecutorKind.PYTHON,
            command=str(script),
            args=["--name", "${name}"],
        ),
    )

    launch = manager._build_launch(tool, {"name": "PopTools"})  # noqa: SLF001

    assert launch == (sys.executable, [str(script), "--name", "PopTools"])


def test_python_kind_executes_inline_source_without_splitting(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    source = 'if __name__ == "__main__":\n    print("hello world")'
    tool = ToolDefinition(
        id="custom.inline-python",
        section=ToolSection.CUSTOM,
        title="Inline Python",
        executor=ExecutorDefinition(
            kind=ExecutorKind.PYTHON,
            command=source,
        ),
    )

    launch = manager._build_launch(tool, {})  # noqa: SLF001

    assert launch == (sys.executable, ["-c", source])


def test_managed_python_execution_uses_runtime_with_venv_dependencies(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("poptools.infrastructure.python_environment.sys.platform", "win32")
    paths = AppPaths(tmp_path)
    runtime = paths.python_runtime_dir / "python.exe"
    venv_python = paths.python_venv_dir / "Scripts" / "python.exe"
    site_packages = paths.python_venv_dir / "Lib" / "site-packages"
    runtime.parent.mkdir(parents=True)
    venv_python.parent.mkdir(parents=True)
    site_packages.mkdir(parents=True)
    runtime.touch()
    venv_python.touch()
    manager = ExecutionManager(paths)
    source = "print('managed')"
    tool = ToolDefinition(
        id="custom.managed-python",
        section=ToolSection.CUSTOM,
        title="Managed Python",
        executor=ExecutorDefinition(kind=ExecutorKind.PYTHON, command=source),
    )

    launch = manager._build_launch(tool, {})  # noqa: SLF001
    environment = manager._build_environment(tool, {}, tmp_path / "output")  # noqa: SLF001

    assert launch == (str(runtime.resolve()), ["-c", source])
    assert environment.value("POPTOOLS_PYTHON_SITE_PACKAGES") == str(
        site_packages.resolve()
    )
    assert environment.value("VIRTUAL_ENV") == str(paths.python_venv_dir)
    assert environment.value("PYTHONPATH").split(os.pathsep)[0] == str(
        resource_path("python")
    )


def test_secret_parameter_is_redacted_from_launch_log(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    tool = ToolDefinition(
        id="custom.secret",
        section=ToolSection.CUSTOM,
        title="Secret command",
        executor=ExecutorDefinition(kind=ExecutorKind.PROCESS, command="tool"),
        parameters=[
            ParameterDefinition(id="token", label="Token", kind=ParameterKind.SECRET)
        ],
    )

    rendered = manager._format_launch_for_log(  # noqa: SLF001
        tool,
        "tool.exe",
        ["--token", "top-secret"],
        {"token": "top-secret"},
    )

    assert "top-secret" not in rendered
    assert "***" in rendered


def test_powershell_source_is_hidden_from_launch_log(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    source = "Write-Output 'should-not-appear'"
    tool = ToolDefinition(
        id="custom.hidden-powershell",
        section=ToolSection.CUSTOM,
        title="Hidden PowerShell",
        executor=ExecutorDefinition(kind=ExecutorKind.POWERSHELL, command=source),
    )

    rendered = manager._format_launch_for_log(  # noqa: SLF001
        tool,
        "powershell.exe",
        ["-NoProfile", "-Command", source],
        {},
    )

    assert "should-not-appear" not in rendered
    assert "[内联 PowerShell 脚本]" in rendered


def test_execution_timeout_stops_process(tmp_path: Path, qtbot) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    messages: list[str] = []
    manager.output.connect(messages.append)
    tool = ToolDefinition(
        id="local.timeout",
        section=ToolSection.CUSTOM,
        title="Timeout",
        executor=ExecutorDefinition(
            kind=ExecutorKind.PROCESS,
            command=sys.executable,
            args=["-c", "import time; time.sleep(10)"],
            timeout_seconds=1,
        ),
    )

    with qtbot.waitSignal(manager.finished, timeout=4_000) as finished:
        assert manager.start(tool, {}) is True

    assert finished.args[0] != 0
    assert manager.running is False
    assert any("运行超时" in message for message in messages)


def test_failed_start_restores_idle_state(tmp_path: Path, qtbot, monkeypatch) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    monkeypatch.setattr(
        manager,
        "_resolve_program",
        lambda _command: str(tmp_path / "missing-program.exe"),
    )
    tool = ToolDefinition(
        id="local.missing",
        section=ToolSection.CUSTOM,
        title="Missing executable",
        executor=ExecutorDefinition(
            kind=ExecutorKind.PROCESS,
            command="missing-program",
        ),
    )

    with qtbot.waitSignal(manager.finished, timeout=2_000) as finished:
        assert manager.start(tool, {}) is True

    assert finished.args == [-1]
    assert manager.running is False

def test_command_output_removes_ansi_control_sequences(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    messages: list[str] = []
    manager.output.connect(messages.append)

    manager._read_stderr(  # noqa: SLF001
        b"\x1b[31;1mPowerShell error\x1b[0m\n"
    )

    assert messages == ["PowerShell error\n"]


def test_child_process_environment_disables_terminal_colors(tmp_path: Path) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    tool = ToolDefinition(
        id="custom.plain-output",
        section=ToolSection.CUSTOM,
        title="Plain output",
        executor=ExecutorDefinition(kind=ExecutorKind.POWERSHELL, command="Write-Output ok"),
    )

    environment = manager._build_environment(tool, {}, tmp_path / "output")  # noqa: SLF001

    assert environment.value("NO_COLOR") == "1"
    assert environment.value("TERM") == "dumb"
