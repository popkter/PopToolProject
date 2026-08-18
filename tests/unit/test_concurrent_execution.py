from __future__ import annotations

from pathlib import Path

from poptools.infrastructure.android_device_service import AndroidDeviceService
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import AndroidController, AppController


class IdleDeviceService(AndroidDeviceService):
    def refresh(self) -> None:
        pass


def build_controller(tmp_path: Path) -> tuple[AppController, ToolRegistry]:
    paths = AppPaths(tmp_path)
    config = ConfigStore(paths)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    coordinator = ExecutionCoordinator(
        ExecutionManager(paths),
        config.max_parallel(),
    )
    android = AndroidController(config, IdleDeviceService())
    android.stopAutoRefresh()
    controller = AppController(
        registry,
        coordinator,
        config,
        android,
    )
    return controller, registry


def test_commands_run_and_stop_independently(tmp_path: Path, qtbot) -> None:
    controller, registry = build_controller(tmp_path)
    script = tmp_path / "wait.py"
    script.write_text("import time; time.sleep(30)", encoding="utf-8")
    first = registry.create_custom(
        title="任务一",
        description="",
        kind="python",
        command=str(script),
    )
    second = registry.create_custom(
        title="任务二",
        description="",
        kind="python",
        command=str(script),
    )

    controller.selectTool(first.id)
    assert controller.runSelected({}) is True
    qtbot.waitUntil(lambda: controller.statusText == "运行中")
    assert controller.statusText == "运行中"

    controller.selectTool(second.id)
    assert controller.running is False
    assert controller.runSelected({}) is True
    qtbot.waitUntil(lambda: controller.running)
    assert len(controller.execution_coordinator._executions) == 2  # noqa: SLF001

    controller.selectTool(first.id)
    controller.stopExecution()
    qtbot.waitUntil(
        lambda: first.id not in controller.execution_coordinator._executions,  # noqa: SLF001
        timeout=5_000,
    )
    assert controller.execution_coordinator._executions[second.id].running is True  # noqa: SLF001

    controller.selectTool(second.id)
    controller.stopExecution()
    qtbot.waitUntil(
        lambda: second.id not in controller.execution_coordinator._executions,  # noqa: SLF001
        timeout=5_000,
    )


def test_scrcpy_does_not_block_other_commands(tmp_path: Path, monkeypatch) -> None:
    controller, registry = build_controller(tmp_path)
    command = registry.create_custom(
        title="并行命令",
        description="",
        kind="python",
        command="print('ok')",
    )
    captured: list[str] = []

    controller.selectTool("preset.android.scrcpy")
    scrcpy = controller.execution_coordinator._scrcpy  # noqa: SLF001
    scrcpy._process = object()  # type: ignore[assignment]  # noqa: SLF001
    scrcpy._started = True  # noqa: SLF001
    controller.execution_coordinator._scrcpy_tool_id = "preset.android.scrcpy"  # noqa: SLF001
    assert controller.running is True

    monkeypatch.setattr(
        controller.execution,
        "start",
        lambda tool, _values: captured.append(tool.id) is None or True,
    )
    controller.selectTool(command.id)
    assert controller.running is False
    assert controller.runSelected({}) is True
    assert captured == [command.id]
    assert scrcpy.running is True
    scrcpy._process = None  # noqa: SLF001
    scrcpy._started = False  # noqa: SLF001


def test_selecting_another_tool_hides_embedded_scrcpy_window(
    tmp_path: Path, monkeypatch
) -> None:
    controller, registry = build_controller(tmp_path)
    command = registry.create_custom(
        title="骞惰鍛戒护",
        description="",
        kind="python",
        command="print('ok')",
    )
    geometry_updates: list[tuple[int, int, int, int, bool]] = []

    def capture_geometry(rect, visible: bool) -> None:
        geometry_updates.append((rect.x(), rect.y(), rect.width(), rect.height(), visible))

    monkeypatch.setattr(
        controller.execution_coordinator._scrcpy,  # noqa: SLF001
        "set_geometry",
        capture_geometry,
    )

    controller.selectTool("preset.android.scrcpy")
    controller.selectTool(command.id)

    assert geometry_updates == [(0, 0, 0, 0, False)]


def test_process_output_is_coalesced_before_updating_console(tmp_path: Path, qtbot) -> None:
    controller, _registry = build_controller(tmp_path)
    changes: list[str] = []
    controller.consoleTextChanged.connect(lambda: changes.append(controller.consoleText))

    for index in range(1_000):
        controller._queue_console("", f"network line {index}\n")  # noqa: SLF001

    assert changes == []
    qtbot.waitUntil(lambda: len(changes) == 1, timeout=1_000)
    assert "network line 0\n" in controller.consoleText
    assert "network line 999\n" in controller.consoleText


def test_clear_console_discards_queued_process_output(tmp_path: Path, qtbot) -> None:
    controller, _registry = build_controller(tmp_path)
    controller._queue_console("", "stale process output\n")  # noqa: SLF001

    controller.clearConsole()
    qtbot.wait(100)

    assert controller.consoleText == ""



def test_capacity_prompt_replaces_the_oldest_ordinary_execution(tmp_path: Path, qtbot) -> None:
    controller, registry = build_controller(tmp_path)
    script = tmp_path / "wait_for_capacity.py"
    script.write_text("import time; time.sleep(30)", encoding="utf-8")
    tools = [
        registry.create_custom(
            title=f"任务{index}",
            description="",
            kind="python",
            command=str(script),
        )
        for index in range(1, 4)
    ]
    prompts: list[tuple[str, str]] = []
    controller.executionCapacityRequested.connect(
        lambda victim, requested: prompts.append((victim, requested))
    )

    controller.selectTool(tools[0].id)
    assert controller.runSelected({}) is True
    qtbot.waitUntil(lambda: controller.running)
    controller.selectTool(tools[1].id)
    assert controller.runSelected({}) is True
    qtbot.waitUntil(lambda: controller.running)

    controller.selectTool(tools[2].id)
    assert controller.runSelected({}) is False
    assert prompts == [("任务1", "任务3")]
    assert tools[2].id not in controller.execution_coordinator._executions  # noqa: SLF001

    controller.cancelExecutionReplacement()
    qtbot.wait(50)
    assert controller.execution_coordinator._pending is None  # noqa: SLF001
    assert tools[2].id not in controller.execution_coordinator._executions  # noqa: SLF001
    assert all(
        controller.execution_coordinator._executions[tool.id].running  # noqa: SLF001
        for tool in tools[:2]
    )

    assert controller.runSelected({}) is False
    assert prompts == [("任务1", "任务3"), ("任务1", "任务3")]

    controller.confirmExecutionReplacement()
    qtbot.waitUntil(
        lambda: (
            tools[0].id not in controller.execution_coordinator._executions  # noqa: SLF001
            and tools[2].id in controller.execution_coordinator._executions  # noqa: SLF001
            and controller.execution_coordinator._executions[tools[2].id].running  # noqa: SLF001
        ),
        timeout=5_000,
    )
    assert controller.execution_coordinator._executions[tools[1].id].running is True  # noqa: SLF001

    for tool in tools[1:]:
        controller.selectTool(tool.id)
        controller.stopExecution()
    qtbot.waitUntil(
        lambda: not controller.execution_coordinator._executions,  # noqa: SLF001
        timeout=5_000,
    )


def test_accepted_process_reports_starting_until_manager_emits_started(
    tmp_path: Path,
    monkeypatch,
) -> None:
    paths = AppPaths(tmp_path)
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(paths))
    manager = ExecutionManager(paths)
    coordinator = ExecutionCoordinator(manager, 3)
    config = ConfigStore(paths)
    android = AndroidController(config, IdleDeviceService())
    android.stopAutoRefresh()
    controller = AppController(
        registry,
        coordinator,
        config,
        android,
    )
    tool = registry.create_custom(
        title="延迟启动",
        description="",
        kind="python",
        command="print('ok')",
    )
    monkeypatch.setattr(manager, "start", lambda _tool, _values: True)

    controller.selectTool(tool.id)
    assert controller.runSelected({}) is True
    assert controller.statusText == "正在启动"

    manager.started.emit()
    assert controller.statusText == "运行中"

