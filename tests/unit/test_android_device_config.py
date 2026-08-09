from pathlib import Path

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths


def test_preferred_android_device_is_persisted(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    store.set_preferred_android_device("emulator-5554")

    assert ConfigStore(AppPaths(tmp_path)).preferred_android_device() == "emulator-5554"
