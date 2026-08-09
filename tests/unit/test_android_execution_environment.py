import os
from pathlib import Path

import pytest

from poptools.domain.models import (
    ExecutorDefinition,
    ExecutorKind,
    ToolDefinition,
    ToolSection,
)
from poptools.paths import AppPaths
from poptools.runners.execution_manager import ExecutionManager


def test_selected_android_device_is_exposed_to_every_runner(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manager = ExecutionManager(AppPaths(tmp_path))
    adb_path = tmp_path / "platform-tools" / "adb.exe"
    monkeypatch.setattr(manager, "_resolve_program", lambda _command: str(adb_path))
    tool = ToolDefinition(
        id="custom.adb",
        section=ToolSection.CUSTOM,
        title="ADB 命令",
        executor=ExecutorDefinition(kind=ExecutorKind.POWERSHELL, command="adb shell id"),
    )

    environment = manager._build_environment(  # noqa: SLF001
        tool,
        {"__android_device__": "emulator-5554"},
        tmp_path / "output",
    )

    assert environment.value("ANDROID_SERIAL") == "emulator-5554"
    assert environment.value("POPTOOLS_EXECUTABLE")
    assert environment.value("PYTHONUNBUFFERED") == "1"
    assert environment.value("POPTOOLS_ADB") == str(adb_path)
    assert environment.value("PATH").split(os.pathsep)[0] == str(adb_path.parent)
    assert environment.value("POPTOOLS_RESOURCE_ROOT").endswith("resources")
    assert environment.value("POPTOOLS_FROZEN") in {"0", "1"}
