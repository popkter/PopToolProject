from pathlib import Path

from poptools.infrastructure.android_device_service import AndroidDeviceService
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.python_doctor import PythonDoctor
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import AndroidController, AppController


class NoopAndroidDeviceService(AndroidDeviceService):
    def refresh(self) -> None:
        pass


def build_controller(
    paths: AppPaths,
    python_doctor: PythonDoctor | None = None,
) -> AppController:
    config = ConfigStore(paths)
    execution = ExecutionManager(paths)
    coordinator = ExecutionCoordinator(execution, config.max_parallel())
    android = AndroidController(config, NoopAndroidDeviceService())
    android.stopAutoRefresh()
    return AppController(
        ToolRegistry(resource_path("tools"), JsonToolRepository(paths)),
        coordinator,
        config,
        android,
        python_doctor=python_doctor,
    )


def test_new_python_command_runs_doctor_and_warns_about_missing_modules(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    controller = build_controller(paths, PythonDoctor(lambda _module: None))
    warnings: list[str] = []
    controller.pythonDoctorWarning.connect(warnings.append)

    assert controller.createCommand("示例", "", "python", "import missing_sdk") is True

    assert warnings
    assert "missing_sdk" in warnings[0]
    assert "Python Doctor 发现缺失依赖：missing_sdk" in controller.consoleText


def test_python_dependency_check_can_be_triggered_explicitly(
    tmp_path: Path,
    monkeypatch,
) -> None:
    paths = AppPaths(tmp_path)
    checked: list[str] = []

    def find_module(module: str) -> object | None:
        checked.append(module)
        return None

    controller = build_controller(paths, PythonDoctor(find_module))
    assert controller.createCommand("需要依赖", "", "python", "import missing_sdk") is True
    checked_after_save = len(checked)
    controller.selectTool(controller._selected.id)  # noqa: SLF001

    started: list[str] = []
    monkeypatch.setattr(
        controller.execution,
        "start",
        lambda tool, _values: started.append(tool.id) or True,
    )

    assert controller.checkSelectedPythonDependencies() is True
    assert len(checked) > checked_after_save
    assert started == []


def test_new_non_python_command_does_not_run_doctor(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)

    def fail_if_called(_module: str) -> object | None:
        raise AssertionError("doctor should not run")

    controller = build_controller(paths, PythonDoctor(fail_if_called))

    assert controller.createCommand("示例", "", "powershell", "Write-Output ok") is True


def test_default_python_doctor_reports_missing_modules_asynchronously(
    tmp_path: Path,
    qtbot,
) -> None:
    paths = AppPaths(tmp_path)
    controller = build_controller(paths)
    warnings: list[str] = []
    controller.pythonDoctorWarning.connect(warnings.append)

    assert controller.createCommand(
        "异步检查",
        "",
        "python",
        "import poptools_module_that_does_not_exist",
    )
    assert warnings == []
    assert "正在异步检查依赖" in controller.consoleText

    qtbot.waitUntil(lambda: bool(warnings), timeout=5_000)
    assert "poptools_module_that_does_not_exist" in warnings[0]


def test_python_dependency_install_rejects_pip_options(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    controller = build_controller(paths)

    assert controller.installPythonDependencies("--index-url https://example.invalid") is False
    assert "不要填写命令选项" in controller.consoleText
