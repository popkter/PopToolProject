from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import urllib.request
import uuid
import zipfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

from poptools.paths import AppPaths, resource_path

ProgressCallback = Callable[[int], None]
DOWNLOAD_TIMEOUT_SECONDS = 120


@dataclass(frozen=True)
class PowerShellPluginPackage:
    version: str
    architecture: str
    url: str
    sha256: str
    size: int


class PowerShellPlugin:
    """Download and materialize the optional official PowerShell ZIP package."""

    def __init__(self, paths: AppPaths, manifest_path: Path | None = None) -> None:
        self.paths = paths
        self.manifest_path = manifest_path or resource_path(
            "vendor", "powershell-plugin.json"
        )
        self.package = self._load_package()

    @property
    def install_directory(self) -> Path:
        return self.paths.powershell_plugin_dir / (
            f"{self.package.version}-{self.package.architecture}"
        )

    @property
    def executable(self) -> Path:
        return self.install_directory / "pwsh.exe"

    def is_installed(self) -> bool:
        installed_manifest = self.install_directory / "plugin.json"
        if not self.executable.is_file() or not installed_manifest.is_file():
            return False
        try:
            installed = json.loads(installed_manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        return bool(
            installed.get("version") == self.package.version
            and installed.get("architecture") == self.package.architecture
            and installed.get("sha256", "").lower() == self.package.sha256
        )

    def install(self, progress: ProgressCallback | None = None) -> Path:
        if self.is_installed():
            if progress:
                progress(100)
            return self.executable

        target = self.install_directory
        parent = target.parent
        parent.mkdir(parents=True, exist_ok=True)
        suffix = uuid.uuid4().hex[:8]
        archive = parent / f".download-{suffix}.zip"
        staging = parent / f".staging-{suffix}"
        try:
            self._download(archive, progress)
            if progress:
                progress(91)
            actual_hash = self._sha256(archive)
            if actual_hash != self.package.sha256:
                raise ValueError("PowerShell 7 插件下载校验失败")
            if progress:
                progress(94)
            staging.mkdir()
            self._extract_safely(archive, staging)
            if not (staging / "pwsh.exe").is_file():
                raise ValueError("PowerShell 7 插件包缺少 pwsh.exe")
            if progress:
                progress(99)
            self._commit_install(staging, target)
            self._write_installed_manifest(target)
            if progress:
                progress(100)
            return self.executable
        finally:
            archive.unlink(missing_ok=True)
            if staging.exists():
                shutil.rmtree(staging)

    @staticmethod
    def _commit_install(staging: Path, target: Path) -> None:
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)
        try:
            shutil.copytree(staging, target, dirs_exist_ok=True)
        except Exception:
            shutil.rmtree(target, ignore_errors=True)
            raise


    def _write_installed_manifest(self, target: Path) -> None:
        (target / "plugin.json").write_text(
            json.dumps(
                {
                    "version": self.package.version,
                    "architecture": self.package.architecture,
                    "sha256": self.package.sha256,
                    "source": self.package.url,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )

    def _download(self, destination: Path, progress: ProgressCallback | None) -> None:
        request = urllib.request.Request(
            self.package.url,
            headers={"User-Agent": "PopTools-PowerShell-Plugin-Installer"},
        )
        with urllib.request.urlopen(
            request, timeout=DOWNLOAD_TIMEOUT_SECONDS
        ) as response, destination.open("wb") as output:
            total = int(response.headers.get("Content-Length") or self.package.size or 0)
            received = 0
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                received += len(chunk)
                if progress and total:
                    progress(min(90, int(received * 90 / total)))

    @staticmethod
    def _sha256(path: Path) -> str:
        with path.open("rb") as stream:
            return hashlib.file_digest(stream, "sha256").hexdigest().lower()

    @staticmethod
    def _extract_safely(archive: Path, destination: Path) -> None:
        with zipfile.ZipFile(archive) as package:
            root = destination.resolve()
            for member in package.infolist():
                relative = PurePosixPath(member.filename)
                if relative.is_absolute() or ".." in relative.parts:
                    raise ValueError("PowerShell 7 插件包包含不安全路径")
                resolved = (destination / Path(*relative.parts)).resolve()
                if os.path.commonpath((root, resolved)) != str(root):
                    raise ValueError("PowerShell 7 插件包包含不安全路径")
            package.extractall(destination)

    def _load_package(self) -> PowerShellPluginPackage:
        manifest: dict[str, Any] = json.loads(
            self.manifest_path.read_text(encoding="utf-8")
        )
        architecture = self._architecture()
        package = manifest.get("packages", {}).get(architecture)
        if not isinstance(package, dict):
            raise RuntimeError(f"PowerShell 7 插件不支持当前架构：{architecture}")
        checksum = str(package.get("sha256", "")).lower()
        if len(checksum) != 64:
            raise ValueError("PowerShell 7 插件清单缺少有效 SHA-256")
        return PowerShellPluginPackage(
            version=str(manifest["version"]),
            architecture=architecture,
            url=str(package["url"]),
            sha256=checksum,
            size=int(package.get("size", 0)),
        )

    @staticmethod
    def _architecture() -> str:
        machine = platform.machine().lower()
        if machine in {"amd64", "x86_64"}:
            return "x64"
        if machine in {"arm64", "aarch64"}:
            return "arm64"
        raise RuntimeError(f"不支持的 Windows 架构：{machine}")
