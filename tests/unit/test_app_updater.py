from __future__ import annotations

import hashlib
import io
from pathlib import Path
from typing import Any

import pytest

from poptools.infrastructure.app_updater import (
    GitHubReleaseClient,
    UpdateRelease,
    is_newer_version,
)


def test_version_comparison_supports_build_dates_and_prereleases() -> None:
    assert is_newer_version("v0.2.0", "2026-08-17_0.1.0-beta")
    assert is_newer_version("0.2.0-beta.2", "0.2.0-beta.1")
    assert is_newer_version("0.2.0-rc1", "0.2.0-beta.9")
    assert is_newer_version("0.2.0", "0.2.0-rc2")
    assert is_newer_version("2026-08-18_0.2.0", "2026-08-17_0.2.0")
    assert is_newer_version("2026-08-01_0.3.0", "2026-09-01_0.2.0")
    assert not is_newer_version("0.1.9", "0.2.0")


def test_release_selection_includes_prereleases_and_requires_the_expected_exe() -> None:
    payload: list[dict[str, Any]] = [
        {
            "tag_name": "v0.2.0-beta.1",
            "name": "Beta",
            "body": "Changes",
            "html_url": "https://github.com/popkter/PopToolProject/releases/tag/v0.2.0-beta.1",
            "draft": False,
            "prerelease": True,
            "assets": [
                {
                    "name": "泡泡工具箱.exe",
                    "browser_download_url": "https://example.test/app.exe",
                    "size": 123,
                    "digest": "sha256:" + "a" * 64,
                },
                {
                    "name": "泡泡工具箱.exe.sha256",
                    "browser_download_url": "https://example.test/app.exe.sha256",
                },
            ],
        },
        {
            "tag_name": "v9.0.0",
            "draft": True,
            "assets": [],
        },
    ]

    release = GitHubReleaseClient.select_latest_release(payload)

    assert release is not None
    assert release.version == "0.2.0-beta.1"
    assert release.asset_size == 123
    assert release.sha256 == "a" * 64
    assert release.checksum_url.endswith(".sha256")


class FakeResponse(io.BytesIO):
    def __init__(self, payload: bytes) -> None:
        super().__init__(payload)
        self.headers = {"Content-Length": str(len(payload))}

    def __enter__(self) -> FakeResponse:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()


def test_update_download_verifies_checksum_and_commits_atomically(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = b"new portable executable"
    release = UpdateRelease(
        version="0.2.0",
        tag="v0.2.0",
        name="0.2.0",
        notes="Changes",
        page_url="https://example.test/release",
        asset_url="https://example.test/app.exe",
        asset_name="泡泡工具箱.exe",
        asset_size=len(payload),
        sha256=hashlib.sha256(payload).hexdigest(),
    )
    monkeypatch.setattr(
        "poptools.infrastructure.app_updater.urllib.request.urlopen",
        lambda *_args, **_kwargs: FakeResponse(payload),
    )
    progress: list[tuple[int, int]] = []
    destination = tmp_path / "update.exe"

    result = GitHubReleaseClient.download(
        release, destination, lambda received, total: progress.append((received, total))
    )

    assert result == destination
    assert destination.read_bytes() == payload
    assert progress[-1] == (len(payload), len(payload))
    assert not destination.with_suffix(".exe.part").exists()


def test_update_download_rejects_a_bad_checksum(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = b"tampered"
    release = UpdateRelease(
        version="0.2.0",
        tag="v0.2.0",
        name="0.2.0",
        notes="",
        page_url="",
        asset_url="https://example.test/app.exe",
        asset_name="泡泡工具箱.exe",
        asset_size=len(payload),
        sha256="0" * 64,
    )
    monkeypatch.setattr(
        "poptools.infrastructure.app_updater.urllib.request.urlopen",
        lambda *_args, **_kwargs: FakeResponse(payload),
    )

    with pytest.raises(ValueError, match="SHA-256"):
        GitHubReleaseClient.download(release, tmp_path / "update.exe")

    assert not (tmp_path / "update.exe").exists()
