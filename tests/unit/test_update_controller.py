from pathlib import Path

from poptools.infrastructure.app_updater import GitHubReleaseClient, UpdateRelease
from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths
from poptools.viewmodels.update_controller import UpdateController


def make_release(version: str = "0.2.0") -> UpdateRelease:
    return UpdateRelease(
        version=version,
        tag=f"v{version}",
        name=f"PopTools {version}",
        notes="New features",
        page_url="https://example.test/release",
        asset_url="https://example.test/app.exe",
        asset_name="泡泡工具箱.exe",
        asset_size=1024,
    )


def test_available_update_can_be_skipped_persistently(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    controller = UpdateController(
        store,
        GitHubReleaseClient("https://example.test/releases"),
        current_version="0.1.0",
        auto_check_enabled=False,
    )
    notifications: list[str] = []
    controller.updateAvailable.connect(lambda: notifications.append(controller.availableVersion))

    controller._on_check_completed(make_release(), "")

    assert controller.state == "available"
    assert controller.availableVersion == "0.2.0"
    assert notifications == ["0.2.0"]

    controller.skipVersion()
    assert ConfigStore(AppPaths(tmp_path)).skipped_update_version() == "0.2.0"

    next_start = UpdateController(
        store,
        current_version="0.1.0",
        auto_check_enabled=False,
    )
    next_notifications: list[bool] = []
    next_start.updateAvailable.connect(lambda: next_notifications.append(True))
    next_start._on_check_completed(make_release(), "")
    assert next_start.state == "idle"
    assert next_notifications == []


def test_older_or_equal_release_is_not_offered(tmp_path: Path) -> None:
    controller = UpdateController(
        ConfigStore(AppPaths(tmp_path)),
        current_version="2026-08-17_0.2.0-beta",
        auto_check_enabled=False,
    )

    controller._on_check_completed(make_release("0.2.0-beta"), "")

    assert controller.state == "idle"


def test_download_progress_is_exposed_for_the_dialog(tmp_path: Path) -> None:
    controller = UpdateController(
        ConfigStore(AppPaths(tmp_path)),
        current_version="0.1.0",
        auto_check_enabled=False,
    )
    controller._on_check_completed(make_release(), "")

    controller._on_download_progress(512, 1024)

    assert controller.downloadProgress == 50
    assert controller.downloadedSize == "512 B"
    assert controller.totalSize == "1.0 KB"
