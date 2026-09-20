from pathlib import Path

import pytest

from poptools.domain.adb_detection import analyze_adb
from poptools.domain.models import ExecutorDefinition, ExecutorKind, ToolDefinition, ToolSection
from poptools.infrastructure.custom_tool_transfer import decode_custom_tool, encode_custom_tool


def make_tool(command, kind="powershell", **executor_options):
    return ToolDefinition(
        id="custom.adb", title="ADB", section=ToolSection.CUSTOM,
        executor=ExecutorDefinition(kind=kind, command=command, **executor_options),
    )


@pytest.mark.parametrize(("kind", "source"), [
    ("powershell", "adb shell getprop"),
    ("powershell", '& "C:\\Program Files\\platform-tools\\adb.exe" shell getprop'),
    ("powershell", 'Write-Host "ready"; adb.exe shell getprop'),
    ("powershell", "if ($true) { adb shell getprop }"),
    ("powershell", "adb `\n shell getprop"),
    ("bash", "echo ready && /opt/android/adb shell getprop"),
    ("bash", "if true; then adb shell getprop; fi"),
    ("bash", "FOO=bar adb shell getprop"),
    ("batch", '@call "C:\\platform tools\\adb.exe" shell getprop'),
    ("batch", "@echo off\r\n@adb shell getprop"),
    ("batch", "adb ^\n shell getprop"),
    ("process", '"C:\\Program Files\\adb.exe" shell getprop'),
    ("python", 'import subprocess\nsubprocess.run(["adb", "shell", "getprop"])'),
    ("python", 'from subprocess import check_output as run\ncmd = ["adb.exe", "shell"]\nrun(cmd)'),
    ("python", 'import os\nos.system("adb shell getprop")'),
    ("python", 'import subprocess as sp\nsp.Popen(args="adb shell getprop")'),
])
def test_detects_real_calls(kind, source):
    result = analyze_adb(make_tool(source, kind))
    assert result.uses_adb and result.needs_device


@pytest.mark.parametrize(("kind", "source"), [
    ("powershell", '# adb shell\nWrite-Host "adb shell"'),
    ("powershell", '$my_adb = "adb"\nWrite-Output "adb; adb shell"'),
    ("powershell", '<# adb shell #>\nWrite-Output ready'),
    ("powershell", 'Write-Output ("adb")'),
    ("powershell", '$text = @"\nadb shell\n"@\nWrite-Output $text'),
    ("powershell", 'Write-Host "text `"; adb shell"'),
    ("powershell", '"adb"'),
    ("bash", r'echo "text \"; adb shell"'),
    ("bash", 'echo "adb shell"\n# adb shell'),
    ("batch", '@REM adb shell\n:: adb shell\necho adb'),
    ("python", '# adb shell\nprint("adb shell")'),
    ("python", 'adb = "adb shell"'),
    ("python", 'subprocess.run(["echo", "adb"])'),
    ("process", "my-adb.exe shell"),
    ("process", "echo adb"),
    ("bash", "cat <<EOF\nadb shell\nEOF"),
])
def test_ignores_comments_and_descriptive_text(kind, source):
    assert not analyze_adb(make_tool(source, kind)).uses_adb


@pytest.mark.parametrize("command", [
    "devices -l", "version", "help", "start-server", "kill-server",
    "connect 127.0.0.1:5555", "disconnect", "-H localhost -P 5037 devices",
])
def test_host_commands_need_no_device(command):
    result = analyze_adb(make_tool("adb " + command))
    assert result.uses_adb and not result.needs_device


@pytest.mark.parametrize("option", ["-s serial1", "-d", "-e", "-t 1"])
def test_explicit_targets_are_preserved(option):
    result = analyze_adb(make_tool(f"adb {option} shell getprop"))
    assert result.explicit_target and not result.needs_device
    mixed = analyze_adb(make_tool(f"adb {option} shell getprop\nadb shell getprop"))
    assert mixed.explicit_target and mixed.needs_device


def test_process_args_are_analyzed():
    result = analyze_adb(make_tool("adb", "process", args=["-s", "serial", "shell"]))
    assert result.explicit_target and not result.needs_device


def test_external_script_is_reread_and_failures_have_manual_fallback(tmp_path):
    path = tmp_path / "script.py"
    path.write_text('import subprocess\nsubprocess.run(["adb", "shell"])', encoding="utf-8")
    tool = make_tool(str(path), "python")
    assert analyze_adb(tool, Path).needs_device
    path.write_text('print("adb")', encoding="utf-8")
    assert not analyze_adb(tool, Path).uses_adb
    path.unlink()
    assert "无法读取" in analyze_adb(tool, Path).reason


def test_declaration_modes_and_round_trip():
    for mode, expected in [("auto", False), ("use", True), ("none", False)]:
        tool = make_tool('run_dynamic_command()', "python", android_device_mode=mode)
        assert analyze_adb(tool).uses_adb == expected
        assert decode_custom_tool(encode_custom_tool(tool)).executor.android_device_mode == mode
    assert not analyze_adb(make_tool("adb shell", android_device_mode="none")).uses_adb
    assert make_tool("echo hi").executor.android_device_mode == "auto"


def test_builtin_dispatcher_uses_per_action_requirements():
    tool = make_tool("dispatcher.py", "python", requirements=["adb"])
    tool.section = ToolSection.PRESET
    assert analyze_adb(tool).uses_adb
    assert not analyze_adb(tool).needs_device
    tool.executor.requirements.append("android_device")
    assert analyze_adb(tool).needs_device


def test_dynamic_code_is_not_executed(tmp_path):
    marker = tmp_path / "never-created"
    tool = make_tool(f'open({str(marker)!r}, "w"); subprocess.run(get_command())', "python")
    assert not analyze_adb(tool).uses_adb
    assert not marker.exists()


@pytest.mark.parametrize("kind", list(ExecutorKind))
def test_empty_commands_do_not_crash(kind):
    assert not analyze_adb(make_tool("", kind)).uses_adb
