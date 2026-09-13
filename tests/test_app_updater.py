from __future__ import annotations

import io
import json
import urllib.request
from pathlib import Path
from typing import Any

from poptools.infrastructure import app_updater
from poptools.infrastructure.app_updater import (
    GitHubReleaseClient,
    UpdateInstaller,
    update_asset_name,
)


def release_payload(version: str) -> dict[str, Any]:
    tag = f"v{version}"
    return {
        "tag_name": tag,
        "name": tag,
        "body": "notes",
        "html_url": f"https://github.com/example/releases/tag/{tag}",
        "draft": False,
        "assets": [
            {
                "name": "PopTools-Setup.exe",
                "browser_download_url": f"https://example.com/{tag}/PopTools-Setup.exe",
                "size": 10,
                "digest": f"sha256:{'a' * 64}",
            }
        ],
    }


def test_windows_update_uses_installer() -> None:
    assert update_asset_name("win32", "AMD64") == "PopTools-Setup.exe"


def test_windows_update_runs_setup_silently(monkeypatch, tmp_path: Path) -> None:
    source = tmp_path / "PopTools-Setup.exe"
    source.write_bytes(b"setup")
    target = tmp_path / "installed" / "泡泡工具箱.exe"
    target.parent.mkdir()
    target.write_bytes(b"application")
    system_root = tmp_path / "Windows"
    powershell = (
        system_root
        / "System32"
        / "WindowsPowerShell"
        / "v1.0"
        / "powershell.exe"
    )
    powershell.parent.mkdir(parents=True)
    powershell.write_bytes(b"powershell")
    launched: dict[str, object] = {}

    class FakeProcess:
        @staticmethod
        def startDetached(
            program: str, arguments: list[str], working_directory: str
        ) -> bool:
            launched.update(
                program=program,
                arguments=arguments,
                working_directory=working_directory,
            )
            return True

    monkeypatch.setenv("SYSTEMROOT", str(system_root))
    monkeypatch.setattr(app_updater, "QProcess", FakeProcess)

    assert UpdateInstaller._launch_windows(source, target) is True
    script = (tmp_path / "apply-poptools-update.ps1").read_text(encoding="utf-8-sig")
    assert "'/VERYSILENT'" in script
    assert "'/SUPPRESSMSGBOXES'" in script
    assert "'/NORESTART'" in script
    assert "Start-Process -FilePath $Source" in script
    assert "Expand-Archive" not in script
    assert launched["working_directory"] == str(target.parent)


def test_windows_update_rejects_archives(tmp_path: Path) -> None:
    archive = tmp_path / "PopTools.zip"
    archive.write_bytes(b"archive")

    assert UpdateInstaller._launch_windows(archive, tmp_path / "泡泡工具箱.exe") is False


def test_prerelease_channel_requests_five_and_selects_highest_version(
    monkeypatch,
) -> None:
    requested_urls = []
    payload = [release_payload("1.0.6"), release_payload("1.0.7-rc1")]

    def fake_urlopen(
        request: urllib.request.Request, **_kwargs: Any
    ) -> io.BytesIO:
        requested_urls.append(request.full_url)
        return io.BytesIO(json.dumps(payload).encode())

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    release = GitHubReleaseClient().latest_release(include_prerelease=True)

    assert requested_urls == [
        "https://api.github.com/repos/popkter/PopToolProject/releases?per_page=5"
    ]
    assert release is not None
    assert release.version == "1.0.7-rc1"


def test_stable_channel_keeps_using_latest_release_object(monkeypatch) -> None:
    requested_urls = []

    def fake_urlopen(
        request: urllib.request.Request, **_kwargs: Any
    ) -> io.BytesIO:
        requested_urls.append(request.full_url)
        return io.BytesIO(json.dumps(release_payload("1.0.7")).encode())

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    release = GitHubReleaseClient().latest_release(include_prerelease=False)

    assert requested_urls == [
        "https://api.github.com/repos/popkter/PopToolProject/releases/latest"
    ]
    assert release is not None
    assert release.version == "1.0.7"
