from __future__ import annotations

import io
import json
import urllib.request
from typing import Any

from poptools.infrastructure.app_updater import GitHubReleaseClient


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
                "name": "PopTools.exe",
                "browser_download_url": f"https://example.com/{tag}/PopTools.exe",
                "size": 10,
                "digest": f"sha256:{'a' * 64}",
            }
        ],
    }


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
