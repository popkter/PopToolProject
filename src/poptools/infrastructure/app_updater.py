from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import sys
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from PySide6.QtCore import QProcess

GITHUB_RELEASES_URL = "https://api.github.com/repos/popkter/PopToolProject/releases?per_page=5"
GITHUB_LATEST_RELEASE_URL = (
    "https://api.github.com/repos/popkter/PopToolProject/releases/latest"
)
# GitHub normalizes non-ASCII release asset filenames. Keep the actual OTA
# filename ASCII-only and use a Chinese display label in the release workflow.


def update_asset_name(
    system: str | None = None, machine: str | None = None
) -> str:
    host = (system or sys.platform).lower()
    if host in {"win32", "windows"}:
        return "PopTools.exe"
    if host in {"darwin", "macos"}:
        architecture = "arm64" if (machine or platform.machine()).lower() in {
            "arm64",
            "aarch64",
        } else "x64"
        return f"PopTools-macos-{architecture}.zip"
    raise RuntimeError(f"不支持自动更新的平台：{host}")


UPDATE_ASSET_NAME = update_asset_name()
NETWORK_TIMEOUT_SECONDS = 30
DOWNLOAD_TIMEOUT_SECONDS = 180


@dataclass(frozen=True)
class UpdateRelease:
    version: str
    tag: str
    name: str
    notes: str
    page_url: str
    asset_url: str
    asset_name: str
    asset_size: int
    sha256: str = ""
    checksum_url: str = ""


def version_key(
    value: str,
) -> tuple[tuple[int, int, int, int], int, int, int, str, int]:
    """Return a comparable key for SemVer-like and generated build versions."""

    candidate = value.strip().lower().removeprefix("v")
    build_date = 0
    dated = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})_(.+)", candidate)
    if dated:
        build_date = int("".join(dated.group(1, 2, 3)))
        candidate = dated.group(4)
    match = re.search(r"(\d+(?:\.\d+){1,3})(.*)$", candidate)
    if not match:
        return (0, 0, 0, 0), 0, 0, 0, candidate, build_date

    parts = [int(part) for part in match.group(1).split(".")]
    padded = (parts + [0, 0, 0, 0])[:4]
    core = (padded[0], padded[1], padded[2], padded[3])
    suffix = str(match.group(2)).split("+", 1)[0].strip("-._")
    if not suffix:
        return core, 1, 0, 0, "", build_date

    prerelease = re.fullmatch(
        r"(a|alpha|b|beta|pre|preview|rc)[-._]?(\d*)", suffix
    )
    if prerelease:
        label = prerelease.group(1)
        ranks: dict[str, int] = {
            "a": 0,
            "alpha": 0,
            "pre": 0,
            "preview": 0,
            "b": 1,
            "beta": 1,
            "rc": 2,
        }
        number = int(prerelease.group(2) or 0)
        return core, 0, ranks[label], number, suffix, build_date
    return core, 0, -1, 0, suffix, build_date


def is_newer_version(candidate: str, current: str) -> bool:
    return version_key(candidate) > version_key(current)


class GitHubReleaseClient:
    """Read public GitHub releases and download the selected application asset."""

    def __init__(
        self,
        releases_url: str = GITHUB_RELEASES_URL,
        latest_release_url: str = GITHUB_LATEST_RELEASE_URL,
    ) -> None:
        self.releases_url = releases_url
        self.latest_release_url = latest_release_url

    def latest_release(self, include_prereleases: bool = False) -> UpdateRelease | None:
        releases_url = self.releases_url if include_prereleases else self.latest_release_url
        request = urllib.request.Request(
            releases_url,
            headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": "PopTools-Updater",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT_SECONDS) as response:
                payload: Any = json.load(response)
        except urllib.error.HTTPError as exc:
            if not include_prereleases and exc.code == 404:
                return None
            raise
        release = self.select_latest_release(payload)
        if release is None or release.sha256 or not release.checksum_url:
            return release
        checksum_request = urllib.request.Request(
            release.checksum_url,
            headers={"User-Agent": "PopTools-Updater"},
        )
        with urllib.request.urlopen(
            checksum_request, timeout=NETWORK_TIMEOUT_SECONDS
        ) as response:
            checksum_text = response.read(512).decode("ascii", errors="ignore")
        checksum_match = re.search(r"\b([0-9a-fA-F]{64})\b", checksum_text)
        return replace(
            release,
            sha256=checksum_match.group(1).lower() if checksum_match else "",
        )

    @staticmethod
    def select_latest_release(
        payload: Any, asset_name: str | None = None
    ) -> UpdateRelease | None:
        if isinstance(payload, dict):
            payload = [payload]
        if not isinstance(payload, list):
            raise ValueError("GitHub Release 返回格式不正确")

        expected_asset = asset_name or UPDATE_ASSET_NAME

        releases: list[UpdateRelease] = []
        for item in payload:
            if not isinstance(item, dict) or item.get("draft") is True:
                continue
            assets = item.get("assets")
            if not isinstance(assets, list):
                continue
            asset = next(
                (
                    value
                    for value in assets
                    if isinstance(value, dict)
                    and str(value.get("name", "")).lower() == expected_asset.lower()
                ),
                None,
            )
            if asset is None:
                continue
            checksum_asset = next(
                (
                    value
                    for value in assets
                    if isinstance(value, dict)
                    and str(value.get("name", "")).lower()
                    == f"{expected_asset}.sha256".lower()
                ),
                None,
            )
            tag = str(item.get("tag_name", "")).strip()
            url = str(asset.get("browser_download_url", "")).strip()
            if not tag or not url.startswith("https://"):
                continue
            digest = str(asset.get("digest") or "").lower()
            checksum = digest.removeprefix("sha256:") if digest.startswith("sha256:") else ""
            if checksum and re.fullmatch(r"[0-9a-f]{64}", checksum) is None:
                checksum = ""
            releases.append(
                UpdateRelease(
                    version=tag.removeprefix("v"),
                    tag=tag,
                    name=str(item.get("name") or tag),
                    notes=str(item.get("body") or "本次发行未提供更新说明。"),
                    page_url=str(item.get("html_url") or ""),
                    asset_url=url,
                    asset_name=str(asset.get("name") or expected_asset),
                    asset_size=max(0, int(asset.get("size") or 0)),
                    sha256=checksum,
                    checksum_url=_https_url(
                        checksum_asset.get("browser_download_url")
                        if checksum_asset
                        else ""
                    ),
                )
            )
        return max(releases, key=lambda release: version_key(release.version), default=None)

    @staticmethod
    def download(
        release: UpdateRelease,
        destination: Path,
        progress: Callable[[int, int], None] | None = None,
        cancelled: Callable[[], bool] | None = None,
    ) -> Path:
        destination.parent.mkdir(parents=True, exist_ok=True)
        partial = destination.with_suffix(destination.suffix + ".part")
        partial.unlink(missing_ok=True)
        request = urllib.request.Request(
            release.asset_url,
            headers={
                "Accept": "application/octet-stream",
                "User-Agent": "PopTools-Updater",
            },
        )
        received = 0
        digest = hashlib.sha256()
        try:
            with urllib.request.urlopen(
                request, timeout=DOWNLOAD_TIMEOUT_SECONDS
            ) as response, partial.open("wb") as output:
                total = int(response.headers.get("Content-Length") or release.asset_size or 0)
                while chunk := response.read(1024 * 1024):
                    if cancelled and cancelled():
                        raise InterruptedError("更新下载已取消")
                    output.write(chunk)
                    digest.update(chunk)
                    received += len(chunk)
                    if progress:
                        progress(received, total)

            if release.asset_size and received != release.asset_size:
                raise ValueError("更新文件大小与 GitHub Release 记录不一致")
            if release.sha256 and digest.hexdigest().lower() != release.sha256:
                raise ValueError("更新文件 SHA-256 校验失败")
            os.replace(partial, destination)
            return destination
        except Exception:
            partial.unlink(missing_ok=True)
            raise


class UpdateInstaller:
    """Replace the running Windows executable or macOS app, then restart it."""

    @staticmethod
    def launch(downloaded: Path, current_executable: Path | None = None) -> bool:
        source = downloaded.resolve()
        target = (current_executable or Path(sys.executable)).resolve()
        if not source.is_file() or not getattr(sys, "frozen", False):
            return False

        if sys.platform == "darwin":
            return UpdateInstaller._launch_macos(source, target)
        if sys.platform != "win32":
            return False

        return UpdateInstaller._launch_windows(source, target)

    @staticmethod
    def _launch_windows(source: Path, target: Path) -> bool:

        script = source.parent / "apply-poptools-update.ps1"
        script.write_text(
            """param(
    [Parameter(Mandatory=$true)][int]$ProcessId,
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Target
)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $ProcessId -Timeout 90 -ErrorAction SilentlyContinue } catch {}
$installed = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        Copy-Item -LiteralPath $Source -Destination $Target -Force
        $installed = $true
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $installed) { exit 1 }
$env:PYINSTALLER_RESET_ENVIRONMENT = '1'
Start-Process -FilePath $Target
Remove-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
""",
            encoding="utf-8-sig",
        )
        powershell = (
            Path(os.environ.get("SYSTEMROOT", r"C:\Windows"))
            / "System32"
            / "WindowsPowerShell"
            / "v1.0"
            / "powershell.exe"
        )
        if not powershell.is_file():
            return False
        result = QProcess.startDetached(
            str(powershell),
            [
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script),
                "-ProcessId",
                str(os.getpid()),
                "-Source",
                str(source),
                "-Target",
                str(target),
            ],
            str(target.parent),
        )
        return result[0] if isinstance(result, tuple) else bool(result)

    @staticmethod
    def _launch_macos(source: Path, executable: Path) -> bool:
        try:
            app_bundle = next(
                parent for parent in executable.parents if parent.suffix == ".app"
            )
        except StopIteration:
            return False
        script = source.parent / "apply-poptools-update.sh"
        script.write_text(
            """#!/bin/sh
set -eu
process_id="$1"
source_archive="$2"
target_app="$3"
for _attempt in $(seq 1 90); do
    if ! kill -0 "$process_id" 2>/dev/null; then break; fi
    sleep 1
done
staging="${source_archive}.staging.$$"
backup="${target_app}/.Contents.backup.$$"
rm -rf "$staging" "$backup"
mkdir -p "$staging"
ditto -x -k "$source_archive" "$staging"
new_app=$(find "$staging" -maxdepth 1 -type d -name '*.app' -print -quit)
if [ -z "$new_app" ]; then rm -rf "$staging"; exit 1; fi
mv "$target_app/Contents" "$backup"
if mv "$new_app/Contents" "$target_app/Contents"; then
    rm -rf "$backup" "$staging" "$source_archive"
    export PYINSTALLER_RESET_ENVIRONMENT=1
    open "$target_app"
    rm -f "$0"
else
    mv "$backup" "$target_app/Contents"
    rm -rf "$staging"
    exit 1
fi
""",
            encoding="utf-8",
        )
        script.chmod(0o700)
        result = QProcess.startDetached(
            "/bin/sh",
            [str(script), str(os.getpid()), str(source), str(app_bundle)],
            str(app_bundle.parent),
        )
        return result[0] if isinstance(result, tuple) else bool(result)


def _https_url(value: object) -> str:
    candidate = str(value or "").strip()
    return candidate if candidate.startswith("https://") else ""
