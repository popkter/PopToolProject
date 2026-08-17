import sys
from pathlib import Path

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import MANAGED_PROVIDER, PythonEnvironment
from poptools.paths import AppPaths


def test_managed_environment_uses_project_python_during_development(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    environment = PythonEnvironment(paths, ConfigStore(paths))

    state = environment.state()

    assert state.provider == MANAGED_PROVIDER
    assert state.available is True
    assert Path(state.executable).resolve() == Path(sys.executable).resolve()
    assert environment.execution_executable() == state.executable
    assert environment.execution_site_packages() is None


def test_managed_environment_runs_with_runtime_and_loads_venv_packages(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.python_runtime_dir.mkdir(parents=True)
    paths.python_venv_dir.joinpath("Scripts").mkdir(parents=True)
    paths.python_venv_dir.joinpath("Lib", "site-packages").mkdir(parents=True)
    paths.python_runtime_dir.joinpath("python.exe").touch()
    paths.python_venv_dir.joinpath("Scripts", "python.exe").touch()
    environment = PythonEnvironment(paths, ConfigStore(paths))

    assert environment.execution_executable() == str(
        paths.python_runtime_dir.joinpath("python.exe").resolve()
    )
    assert environment.execution_site_packages() == str(
        paths.python_venv_dir.joinpath("Lib", "site-packages").resolve()
    )


def test_managed_environment_preserves_windows_path_case_insensitively(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path)
    paths.python_venv_dir.joinpath("Scripts").mkdir(parents=True)
    paths.python_venv_dir.joinpath("Lib", "site-packages").mkdir(parents=True)
    paths.python_venv_dir.joinpath("Scripts", "python.exe").touch()
    environment = PythonEnvironment(paths, ConfigStore(paths))
    values = environment.execution_environment(
        {"Path": r"C:\PopTools\adb;C:\Windows", "PythonPath": r"C:\custom"}
    )

    assert "Path" not in values
    assert "PythonPath" not in values
    assert r"C:\PopTools\adb;C:\Windows" in values["PATH"]
    assert r"C:\custom" in values["PYTHONPATH"]


def test_legacy_custom_python_setting_is_migrated_to_managed(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    store = ConfigStore(paths)
    store.save_config(
        {
            "python": {"provider": "custom", "custom_executable": "C:/old/python.exe"}
        }
    )

    assert store.python_environment() == (MANAGED_PROVIDER, "")
    assert store.load_config()["python"] == {
        "provider": "managed",
        "custom_executable": None,
    }


def test_missing_pip_is_bootstrapped_from_ensurepip(tmp_path: Path, monkeypatch) -> None:
    paths = AppPaths(tmp_path)
    environment = PythonEnvironment(paths, ConfigStore(paths))
    calls: list[list[str]] = []

    class Result:
        def __init__(self, returncode: int, stderr: str = "") -> None:
            self.returncode = returncode
            self.stderr = stderr
            self.stdout = ""

    def run(command: list[str], **_kwargs) -> Result:
        calls.append(command)
        if len(calls) == 1:
            return Result(1, "No module named pip")
        return Result(0)

    monkeypatch.setattr("poptools.infrastructure.python_environment.subprocess.run", run)

    assert environment.ensure_pip() == (True, "")
    assert calls[0][-3:] == ["-m", "pip", "--version"]
    assert calls[1][-3:] == ["-m", "ensurepip", "--upgrade"]
    assert calls[2][-3:] == ["-m", "pip", "--version"]
