from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import uuid
import zipfile
from dataclasses import dataclass
from pathlib import Path

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths, resource_path

MANAGED_PROVIDER = "managed"
CUSTOM_PROVIDER = "custom"
PYTHON_PROVIDERS = (MANAGED_PROVIDER, CUSTOM_PROVIDER)


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
        self._validated_executables: set[Path] = set()

    @property
    def managed_executable(self) -> Path:
        return self.paths.python_venv_dir / "Scripts" / "python.exe"

    def state(self) -> PythonEnvironmentState:
        provider, custom = self.config_store.python_environment()
        if provider == CUSTOM_PROVIDER:
            executable = Path(custom) if custom else None
            if executable and executable.is_file():
                return PythonEnvironmentState(
                    provider, str(executable.resolve()), True, "正在使用自定义 Python 解释器"
                )
            return PythonEnvironmentState(
                provider,
                custom,
                False,
                "自定义 Python 解释器不可用，请重新选择",
            )

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

    def configure(self, provider: str, custom_executable: str = "") -> PythonEnvironmentState:
        if provider not in PYTHON_PROVIDERS:
            raise ValueError("未知的 Python 环境类型")
        _, saved_custom = self.config_store.python_environment()
        selected_custom = custom_executable.strip().strip('"')
        custom = selected_custom or saved_custom
        if (
            provider == MANAGED_PROVIDER
            and getattr(sys, "frozen", False)
            and not self.managed_executable.is_file()
        ):
            prepare_managed_python(self.paths)
        if provider == CUSTOM_PROVIDER:
            if not custom:
                raise ValueError("请选择 Python 解释器")
            if not self._is_python(Path(custom)):
                raise ValueError("所选文件不是可用的 Python 3.11+ 解释器")
        self.config_store.set_python_environment(provider, custom)
        return self.state()

    def _is_python(self, executable: Path) -> bool:
        if executable in self._validated_executables:
            return True
        if not executable.is_file():
            return False
        try:
            version_source = "import sys; print(sys.version_info.major, sys.version_info.minor)"
            result = subprocess.run(
                [str(executable), "-c", version_source],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except (OSError, subprocess.TimeoutExpired):
            return False
        try:
            version = tuple(int(item) for item in result.stdout.split())
        except ValueError:
            version = ()
        valid = result.returncode == 0 and version >= (3, 11)
        if valid:
            self._validated_executables.add(executable)
        return valid


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
