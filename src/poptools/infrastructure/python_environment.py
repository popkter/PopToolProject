from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import uuid
import zipfile
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths, resource_path

MANAGED_PROVIDER = "managed"


@dataclass(frozen=True)
class PythonEnvironmentState:
    provider: str
    executable: str
    available: bool
    status: str


class PythonEnvironment:
    """Resolve the one interpreter used by Doctor, pip and user scripts."""

    def __init__(self, paths: AppPaths, config_store: ConfigStore) -> None:
        self.paths = paths
        self.config_store = config_store

    @property
    def managed_executable(self) -> Path:
        return self.paths.python_venv_dir / "Scripts" / "python.exe"

    @property
    def managed_runtime_executable(self) -> Path:
        return self.paths.python_runtime_dir / "python.exe"

    @property
    def managed_site_packages(self) -> Path:
        return self.paths.python_venv_dir / "Lib" / "site-packages"

    def state(self) -> PythonEnvironmentState:
        provider, _ = self.config_store.python_environment()
        managed = self.managed_executable
        if managed.is_file():
            return PythonEnvironmentState(
                provider, str(managed.resolve()), True, "PopTools 专用 Python 环境已就绪"
            )
        if not getattr(sys, "frozen", False) and Path(sys.executable).is_file():
            return PythonEnvironmentState(
                provider,
                str(Path(sys.executable).resolve()),
                True,
                "开发模式：正在使用项目 Python 环境",
            )
        return PythonEnvironmentState(
            provider, str(managed), False, "PopTools 专用 Python 环境尚未就绪"
        )

    def executable(self) -> str | None:
        state = self.state()
        return state.executable if state.available else None

    def execution_executable(self) -> str | None:
        """Return a real CPython process while dependencies remain in the venv.

        A Windows venv executable may be a redirector that immediately starts a
        second process. Console automation packages such as wexpect associate
        IPC resources with the first process ID, so scripts must run with the
        bundled runtime executable itself.
        """
        if self.managed_executable.is_file() and self.managed_runtime_executable.is_file():
            return str(self.managed_runtime_executable.resolve())
        return self.executable()

    def execution_site_packages(self) -> str | None:
        if self.managed_executable.is_file() and self.managed_site_packages.is_dir():
            return str(self.managed_site_packages.resolve())
        return None

    def execution_environment(
        self, base: Mapping[str, str] | None = None
    ) -> dict[str, str]:
        environment = dict(os.environ if base is None else base)
        site_packages = self.execution_site_packages()
        if not site_packages:
            return environment
        bootstrap_dir = str(resource_path("python"))
        python_path = _pop_environment_value(environment, "PYTHONPATH")
        environment["PYTHONPATH"] = os.pathsep.join(
            part for part in (bootstrap_dir, python_path) if part
        )
        environment["POPTOOLS_PYTHON_SITE_PACKAGES"] = site_packages
        environment["VIRTUAL_ENV"] = str(self.paths.python_venv_dir)
        current_path = _pop_environment_value(environment, "PATH")
        environment["PATH"] = (
            f"{self.paths.python_venv_dir / 'Scripts'}{os.pathsep}{current_path}"
        )
        return environment

    def ensure_pip(self) -> tuple[bool, str]:
        """Make sure the managed interpreter has pip, including legacy venvs."""
        executable = self.executable()
        if not executable:
            return False, "应用内 Python 环境尚未就绪"

        pip_check = subprocess.run(
            [executable, "-m", "pip", "--version"],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        if pip_check.returncode == 0:
            return True, ""

        bootstrap = subprocess.run(
            [executable, "-m", "ensurepip", "--upgrade"],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        if bootstrap.returncode != 0:
            detail = bootstrap.stderr.strip() or bootstrap.stdout.strip()
            return False, detail or f"退出码 {bootstrap.returncode}"

        pip_check = subprocess.run(
            [executable, "-m", "pip", "--version"],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        if pip_check.returncode != 0:
            detail = pip_check.stderr.strip() or pip_check.stdout.strip()
            return False, detail or "pip 安装后仍不可用"
        return True, ""

    def ensure_ready(self) -> PythonEnvironmentState:
        if getattr(sys, "frozen", False) and not self.managed_executable.is_file():
            prepare_managed_python(self.paths)
        return self.state()


def prepare_managed_python(paths: AppPaths) -> Path:
    """Install the bundled private CPython and create its disposable venv."""

    venv_python = paths.python_venv_dir / "Scripts" / "python.exe"
    if venv_python.is_file():
        return venv_python

    vendor_dir = resource_path("vendor", "python")
    manifest_path = vendor_dir / "python-runtime.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    archive = vendor_dir / str(manifest["file"])
    expected = str(manifest["sha256"]).lower()
    if not archive.is_file() or _sha256(archive) != expected:
        raise ValueError("内置 Python 运行时包不存在或校验失败")

    runtime_python = paths.python_runtime_dir / "python.exe"
    if not runtime_python.is_file():
        paths.python_runtime_dir.parent.mkdir(parents=True, exist_ok=True)
        staging = paths.python_dir / f".runtime-{uuid.uuid4().hex}"
        try:
            with zipfile.ZipFile(archive) as package:
                package.extractall(staging)
            extracted = staging / "tools"
            if not (extracted / "python.exe").is_file():
                raise ValueError("内置 Python 运行时包缺少 python.exe")
            if paths.python_runtime_dir.exists():
                shutil.rmtree(paths.python_runtime_dir)
            shutil.copytree(extracted, paths.python_runtime_dir)
        finally:
            if staging.exists():
                shutil.rmtree(staging)

    paths.python_venv_dir.parent.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(
        [str(runtime_python), "-m", "venv", str(paths.python_venv_dir)],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if completed.returncode != 0 or not venv_python.is_file():
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"专用 Python 虚拟环境创建失败：{detail}")
    return venv_python


def _sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def _pop_environment_value(environment: dict[str, str], name: str) -> str:
    if os.name != "nt":
        return environment.pop(name, "")
    matching_keys = [key for key in environment if key.casefold() == name.casefold()]
    value = environment[matching_keys[-1]] if matching_keys else ""
    for key in matching_keys:
        environment.pop(key, None)
    return value
