import sys
from pathlib import Path

import pytest

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import (
    CUSTOM_PROVIDER,
    MANAGED_PROVIDER,
    PythonEnvironment,
)
from poptools.paths import AppPaths


def test_managed_environment_uses_project_python_during_development(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    environment = PythonEnvironment(paths, ConfigStore(paths))

    state = environment.state()

    assert state.provider == MANAGED_PROVIDER
    assert state.available is True
    assert Path(state.executable).resolve() == Path(sys.executable).resolve()


def test_custom_python_is_saved_and_resolved(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    store = ConfigStore(paths)
    environment = PythonEnvironment(paths, store)

    state = environment.configure(CUSTOM_PROVIDER, sys.executable)

    assert state.available is True
    assert state.provider == CUSTOM_PROVIDER
    assert Path(state.executable).resolve() == Path(sys.executable).resolve()
    assert store.python_environment() == (CUSTOM_PROVIDER, sys.executable)


def test_switching_to_managed_preserves_and_reuses_custom_python(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    store = ConfigStore(paths)
    environment = PythonEnvironment(paths, store)

    environment.configure(CUSTOM_PROVIDER, sys.executable)
    environment.configure(MANAGED_PROVIDER)

    assert store.python_environment() == (MANAGED_PROVIDER, sys.executable)
    assert store.custom_python_executable() == sys.executable

    restored = environment.configure(CUSTOM_PROVIDER)

    assert restored.provider == CUSTOM_PROVIDER
    assert restored.available is True
    assert Path(restored.executable).resolve() == Path(sys.executable).resolve()
    assert store.python_environment() == (CUSTOM_PROVIDER, sys.executable)


def test_custom_python_must_be_a_working_python_311_or_newer(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    invalid = tmp_path / "python.exe"
    environment = PythonEnvironment(paths, ConfigStore(paths))

    with pytest.raises(ValueError, match=r"Python 3\.11\+"):
        environment.configure(CUSTOM_PROVIDER, str(invalid))
