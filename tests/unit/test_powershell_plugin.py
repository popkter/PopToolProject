from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path

import pytest

from poptools.infrastructure.powershell_plugin import PowerShellPlugin
from poptools.paths import AppPaths


def _plugin(tmp_path: Path, archive: Path, checksum: str) -> PowerShellPlugin:
    manifest = tmp_path / "powershell-plugin.json"
    manifest.write_text(
        json.dumps(
            {
                "version": "7.6.3-test",
                "packages": {
                    "x64": {
                        "url": archive.as_uri(),
                        "sha256": checksum,
                        "size": archive.stat().st_size,
                    },
                    "arm64": {
                        "url": archive.as_uri(),
                        "sha256": checksum,
                        "size": archive.stat().st_size,
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    return PowerShellPlugin(AppPaths(tmp_path / "data"), manifest)


def test_powershell_plugin_installs_verified_zip_to_user_data(tmp_path: Path) -> None:
    archive = tmp_path / "pwsh.zip"
    with zipfile.ZipFile(archive, "w") as package:
        package.writestr("pwsh.exe", b"test executable")
        package.writestr("LICENSE.txt", "MIT")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    plugin = _plugin(tmp_path, archive, checksum)
    progress: list[int] = []

    executable = plugin.install(progress.append)

    assert executable == plugin.install_directory / "pwsh.exe"
    assert executable.read_bytes() == b"test executable"
    assert plugin.is_installed() is True
    assert progress[-1] == 100
    assert plugin.install_directory.is_relative_to(plugin.paths.data_dir)


def test_powershell_plugin_rejects_checksum_mismatch(tmp_path: Path) -> None:
    archive = tmp_path / "pwsh.zip"
    with zipfile.ZipFile(archive, "w") as package:
        package.writestr("pwsh.exe", b"tampered")
    plugin = _plugin(tmp_path, archive, "0" * 64)

    with pytest.raises(ValueError, match="下载校验失败"):
        plugin.install()

    assert plugin.is_installed() is False
    assert not plugin.install_directory.exists()


def test_powershell_plugin_rejects_zip_path_traversal(tmp_path: Path) -> None:
    archive = tmp_path / "pwsh.zip"
    with zipfile.ZipFile(archive, "w") as package:
        package.writestr("pwsh.exe", b"test executable")
        package.writestr("../escaped.txt", b"unsafe")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    plugin = _plugin(tmp_path, archive, checksum)

    with pytest.raises(ValueError, match="不安全路径"):
        plugin.install()

    assert not (tmp_path / "data" / "plugins" / "escaped.txt").exists()


def test_powershell_plugin_commit_replaces_existing_install(tmp_path: Path) -> None:
    target = tmp_path / "target"
    target.mkdir()
    (target / "old.txt").write_text("old", encoding="utf-8")
    staging = tmp_path / "staging"
    staging.mkdir()
    (staging / "new.txt").write_text("new", encoding="utf-8")

    PowerShellPlugin._commit_install(staging, target)  # noqa: SLF001

    assert not (target / "old.txt").exists()
    assert (target / "new.txt").read_text(encoding="utf-8") == "new"
    assert staging.exists()


def test_install_marker_is_written_only_after_files_are_committed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    archive = tmp_path / "pwsh.zip"
    with zipfile.ZipFile(archive, "w") as package:
        package.writestr("pwsh.exe", b"test executable")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    plugin = _plugin(tmp_path, archive, checksum)

    def fail_commit(_staging: Path, _target: Path) -> None:
        raise PermissionError("copy denied")

    monkeypatch.setattr(plugin, "_commit_install", fail_commit)

    with pytest.raises(PermissionError, match="copy denied"):
        plugin.install()

    assert not (plugin.install_directory / "plugin.json").exists()
    assert plugin.is_installed() is False


def test_install_cancellation_checkpoint_runs_before_files_are_committed(
    tmp_path: Path,
) -> None:
    archive = tmp_path / "pwsh.zip"
    with zipfile.ZipFile(archive, "w") as package:
        package.writestr("pwsh.exe", b"test executable")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    plugin = _plugin(tmp_path, archive, checksum)

    def cancel_before_commit(progress: int) -> None:
        if progress == 99:
            raise RuntimeError("PowerShell 7 插件安装已取消")

    with pytest.raises(RuntimeError, match="安装已取消"):
        plugin.install(cancel_before_commit)

    assert plugin.is_installed() is False
    assert not plugin.install_directory.exists()
