from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
import uuid
import zipfile
from dataclasses import dataclass
from pathlib import Path

from platformdirs import user_data_path

ANDROID_TOOLS_DIR_ENV = "POPTOOLS_ANDROID_TOOLS_DIR"
REQUIRED_ANDROID_TOOL_FILES = ("adb.exe", "scrcpy.exe", "scrcpy-server", "SDL3.dll")


def package_root() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "poptools"
    return Path(__file__).resolve().parent


def resource_path(*parts: str) -> Path:
    return package_root().joinpath("resources", *parts)


def bundled_android_tools_dir() -> Path:
    override = os.environ.get(ANDROID_TOOLS_DIR_ENV)
    return Path(override) if override else resource_path("scrcpy")


def bundled_adb_path() -> Path:
    return bundled_android_tools_dir() / "adb.exe"


def bundled_scrcpy_path() -> Path:
    return bundled_android_tools_dir() / "scrcpy.exe"


def prepare_bundled_android_tools(paths: AppPaths) -> Path:
    """Extract the verified official archive to a persistent versioned directory."""

    vendor_dir = resource_path("vendor")
    manifest_file = vendor_dir / "scrcpy-manifest.json"
    if not manifest_file.is_file():
        raise FileNotFoundError("内置 scrcpy 清单不存在")
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("内置 scrcpy 清单格式错误")

    archive = vendor_dir / str(manifest.get("archive", ""))
    expected_checksum = str(manifest.get("sha256", "")).lower()
    if not archive.is_file() or _sha256(archive) != expected_checksum:
        raise ValueError("内置 scrcpy 发行包校验失败")

    version = str(manifest.get("version", "unknown"))
    release_name = f"scrcpy-{version}-{expected_checksum[:12]}"
    target = paths.runtime_dir / release_name
    if _android_tools_are_ready(target, manifest):
        os.environ[ANDROID_TOOLS_DIR_ENV] = str(target)
        return target

    paths.runtime_dir.mkdir(parents=True, exist_ok=True)
    staging = paths.runtime_dir / f".{release_name}.{uuid.uuid4().hex}"
    try:
        with zipfile.ZipFile(archive) as package:
            package.extractall(staging)
        extracted = staging / f"scrcpy-win64-v{version}"
        if not all((extracted / name).is_file() for name in REQUIRED_ANDROID_TOOL_FILES):
            raise ValueError("内置 scrcpy 发行包缺少必要文件")
        shutil.copy2(vendor_dir / "scrcpy-LICENSE.txt", extracted / "LICENSE.txt")
        shutil.copy2(manifest_file, extracted / "manifest.json")
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(extracted, target)
    finally:
        if staging.exists():
            shutil.rmtree(staging)

    os.environ[ANDROID_TOOLS_DIR_ENV] = str(target)
    return target


def _sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def _android_tools_are_ready(directory: Path, manifest: dict[str, object]) -> bool:
    manifest_file = directory / "manifest.json"
    if not all((directory / name).is_file() for name in REQUIRED_ANDROID_TOOL_FILES):
        return False
    try:
        installed = json.loads(manifest_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return bool(installed == manifest)


@dataclass(frozen=True)
class AppPaths:
    data_dir: Path

    @classmethod
    def from_environment(cls) -> AppPaths:
        override = os.environ.get("POPTOOLS_DATA_DIR")
        data_dir = Path(override) if override else Path(user_data_path("PopTools", appauthor=False))
        return cls(data_dir=data_dir)

    @property
    def config_file(self) -> Path:
        return self.data_dir / "config.json"

    @property
    def overrides_dir(self) -> Path:
        return self.data_dir / "tools" / "overrides"

    @property
    def custom_dir(self) -> Path:
        return self.data_dir / "tools" / "custom"

    @property
    def scripts_dir(self) -> Path:
        return self.data_dir / "scripts"

    @property
    def outputs_dir(self) -> Path:
        return self.data_dir / "outputs"

    @property
    def backups_dir(self) -> Path:
        return self.data_dir / "backups"

    @property
    def logs_dir(self) -> Path:
        return self.data_dir / "logs"

    @property
    def runtime_dir(self) -> Path:
        return self.data_dir / "runtime"

    @property
    def python_dir(self) -> Path:
        return self.data_dir / "python"

    @property
    def python_runtime_dir(self) -> Path:
        return self.python_dir / "runtime"

    @property
    def python_venv_dir(self) -> Path:
        return self.python_dir / "venv"

    @property
    def plugins_dir(self) -> Path:
        return self.data_dir / "plugins"

    @property
    def updates_dir(self) -> Path:
        return self.data_dir / "updates"

    @property
    def powershell_plugin_dir(self) -> Path:
        return self.plugins_dir / "powershell"

    def ensure(self) -> None:
        for path in (
            self.data_dir,
            self.overrides_dir,
            self.custom_dir,
            self.scripts_dir,
            self.outputs_dir,
            self.backups_dir,
            self.logs_dir,
            self.runtime_dir,
            self.plugins_dir,
            self.updates_dir,
        ):
            path.mkdir(parents=True, exist_ok=True)
