from __future__ import annotations

import logging
import os
import sys
import urllib.error
from pathlib import Path

from PySide6.QtCore import Property, QCoreApplication, QObject, QThread, Signal, Slot

from poptools import __version__
from poptools.infrastructure.app_updater import (
    GitHubReleaseClient,
    UpdateInstaller,
    UpdateRelease,
    is_newer_version,
)
from poptools.infrastructure.config_store import ConfigStore

logger = logging.getLogger(__name__)


class UpdateCheckThread(QThread):
    completed = Signal(object, str)

    def __init__(
        self,
        client: GitHubReleaseClient,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.client = client

    def run(self) -> None:
        try:
            self.completed.emit(self.client.latest_release(), "")
        except urllib.error.HTTPError as exc:
            self.completed.emit(None, f"检查更新失败：GitHub 返回 HTTP {exc.code}")
        except urllib.error.URLError as exc:
            self.completed.emit(None, f"检查更新失败：{exc.reason}")
        except Exception as exc:
            self.completed.emit(None, f"检查更新失败：{exc}")


class UpdateDownloadThread(QThread):
    progressChanged = Signal(int, int)
    completed = Signal(bool, str, str)

    def __init__(
        self,
        client: GitHubReleaseClient,
        release: UpdateRelease,
        destination: Path,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.client = client
        self.release = release
        self.destination = destination

    def run(self) -> None:
        try:
            result = self.client.download(
                self.release,
                self.destination,
                self._report_progress,
                self.isInterruptionRequested,
            )
        except InterruptedError:
            self.completed.emit(False, "更新下载已取消", "")
        except urllib.error.URLError as exc:
            self.completed.emit(False, f"更新下载失败：{exc.reason}", "")
        except Exception as exc:
            self.completed.emit(False, f"更新下载失败：{exc}", "")
        else:
            self.completed.emit(True, "更新下载完成，可以安装并重启。", str(result))

    def _report_progress(self, received: int, total: int) -> None:
        self.progressChanged.emit(received, total)


class UpdateController(QObject):
    stateChanged = Signal()
    updateAvailable = Signal()

    def __init__(
        self,
        config_store: ConfigStore,
        client: GitHubReleaseClient | None = None,
        current_version: str = __version__,
        auto_check_enabled: bool | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.config_store = config_store
        self.client = client or GitHubReleaseClient()
        self._current_version = current_version
        self._auto_check_enabled = (
            getattr(sys, "frozen", False)
            or os.environ.get("POPTOOLS_ENABLE_UPDATE_CHECK") == "1"
            if auto_check_enabled is None
            else auto_check_enabled
        )
        self._state = "idle"
        self._status = ""
        self._release: UpdateRelease | None = None
        self._progress = 0
        self._received_bytes = 0
        self._total_bytes = 0
        self._downloaded_path = ""
        self._check_thread: UpdateCheckThread | None = None
        self._download_thread: UpdateDownloadThread | None = None

    @Property(str, constant=True)
    def currentVersion(self) -> str:
        return self._current_version

    @Property(str, notify=stateChanged)
    def state(self) -> str:
        return self._state

    @Property(str, notify=stateChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=stateChanged)
    def availableVersion(self) -> str:
        return self._release.version if self._release else ""

    @Property(str, notify=stateChanged)
    def releaseName(self) -> str:
        return self._release.name if self._release else ""

    @Property(str, notify=stateChanged)
    def releaseNotes(self) -> str:
        return self._release.notes if self._release else ""

    @Property(str, notify=stateChanged)
    def releasePageUrl(self) -> str:
        return self._release.page_url if self._release else ""

    @Property(int, notify=stateChanged)
    def downloadProgress(self) -> int:
        return self._progress

    @Property(str, notify=stateChanged)
    def downloadedSize(self) -> str:
        return self._format_size(self._received_bytes)

    @Property(str, notify=stateChanged)
    def totalSize(self) -> str:
        return self._format_size(self._total_bytes)

    @Slot(result=bool)
    def checkForUpdates(self) -> bool:
        if not self._auto_check_enabled or self._check_thread is not None:
            return False
        if self._download_thread is not None:
            return False
        self._set_state("checking", "正在检查更新…")
        thread = UpdateCheckThread(self.client, self)
        self._check_thread = thread
        thread.completed.connect(self._on_check_completed)
        thread.finished.connect(thread.deleteLater)
        thread.start()
        return True

    @Slot(result=bool)
    def downloadUpdate(self) -> bool:
        release = self._release
        if release is None or self._download_thread is not None:
            return False
        safe_version = re_safe_filename(release.version)
        destination = self.config_store.paths.updates_dir / f"PopTools-{safe_version}.exe"
        self._progress = 0
        self._received_bytes = 0
        self._total_bytes = release.asset_size
        self._downloaded_path = ""
        self._set_state("downloading", "正在下载更新…")
        thread = UpdateDownloadThread(self.client, release, destination, self)
        self._download_thread = thread
        thread.progressChanged.connect(self._on_download_progress)
        thread.completed.connect(self._on_download_completed)
        thread.finished.connect(thread.deleteLater)
        thread.start()
        return True

    @Slot(result=bool)
    def cancelDownload(self) -> bool:
        thread = self._download_thread
        if thread is None:
            return False
        thread.requestInterruption()
        self._status = "正在取消下载…"
        self.stateChanged.emit()
        return True

    @Slot()
    def skipVersion(self) -> None:
        if self._release is not None:
            self.config_store.set_skipped_update_version(self._release.version)
        self._set_state("idle", "")

    @Slot(result=bool)
    def installAndRestart(self) -> bool:
        if self._state != "downloaded" or not self._downloaded_path:
            return False
        try:
            launched = UpdateInstaller.launch(Path(self._downloaded_path))
        except OSError as exc:
            self._set_state("error", f"无法启动更新程序：{exc}")
            return False
        if not launched:
            self._set_state("error", "无法启动更新程序，请手动下载最新版本。")
            return False
        self._set_state("installing", "正在退出并安装更新…")
        QCoreApplication.quit()
        return True

    @Slot()
    def shutdown(self) -> None:
        for thread in (self._check_thread, self._download_thread):
            if thread is not None and thread.isRunning():
                thread.requestInterruption()
                thread.wait(3_000)

    @Slot(object, str)
    def _on_check_completed(self, release: object, error: str) -> None:
        self._check_thread = None
        if error:
            logger.warning("%s", error)
            self._set_state("idle", "")
            return
        if not isinstance(release, UpdateRelease):
            self._set_state("idle", "")
            return
        if not is_newer_version(release.version, self._current_version):
            self._set_state("idle", "")
            return
        if release.version == self.config_store.skipped_update_version():
            self._set_state("idle", "")
            return
        self._release = release
        self._set_state("available", f"发现新版本 {release.version}")
        self.updateAvailable.emit()

    @Slot(int, int)
    def _on_download_progress(self, received: int, total: int) -> None:
        self._received_bytes = received
        self._total_bytes = total or self._total_bytes
        self._progress = (
            min(100, int(received * 100 / self._total_bytes))
            if self._total_bytes
            else 0
        )
        self._status = (
            f"正在下载… {self._progress}%"
            if self._total_bytes
            else f"正在下载… {self._format_size(received)}"
        )
        self.stateChanged.emit()

    @Slot(bool, str, str)
    def _on_download_completed(self, success: bool, message: str, path: str) -> None:
        self._download_thread = None
        if success:
            self._progress = 100
            self._downloaded_path = path
            self._set_state("downloaded", message)
        elif message == "更新下载已取消":
            self._set_state("available", message)
        else:
            self._set_state("error", message)

    def _set_state(self, state: str, status: str) -> None:
        self._state = state
        self._status = status
        self.stateChanged.emit()

    @staticmethod
    def _format_size(value: int) -> str:
        if value <= 0:
            return ""
        if value >= 1024 * 1024:
            return f"{value / (1024 * 1024):.1f} MB"
        if value >= 1024:
            return f"{value / 1024:.1f} KB"
        return f"{value} B"


def re_safe_filename(value: str) -> str:
    return "".join(
        character if character.isalnum() or character in ".-_" else "_"
        for character in value
    )
