import json
from pathlib import Path

import pytest

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.paths import AppPaths
from poptools.viewmodels.settings_controller import SettingsController


def test_config_round_trip(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    config = store.load_config()
    config["app"]["last_section"] = "preset"
    store.save_config(config)
    assert store.load_config()["app"]["last_section"] == "preset"


def test_default_parallel_capacity_reserves_one_slot_for_scrcpy(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.max_parallel() == 3


def test_terminal_feature_defaults_off_and_round_trips(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.terminal_enabled() is False
    store.set_terminal_enabled(True)
    assert ConfigStore(AppPaths(tmp_path)).terminal_enabled() is True
    store.set_terminal_enabled(False)
    assert ConfigStore(AppPaths(tmp_path)).terminal_enabled() is False


def test_settings_controller_publishes_terminal_feature_changes(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path)
    store = ConfigStore(paths)
    controller = SettingsController(store, PythonEnvironment(paths, store))
    changes: list[bool] = []
    controller.terminalEnabledChanged.connect(
        lambda: changes.append(controller.terminalEnabled)
    )

    assert controller.terminalEnabled is False
    assert controller.saveTerminalEnabled(True) is True
    assert changes == [True]
    assert ConfigStore(paths).terminal_enabled() is True

    assert controller.saveTerminalEnabled(False) is True
    assert changes == [True, False]
    assert ConfigStore(paths).terminal_enabled() is False


def test_custom_script_concurrency_is_limited_to_one_through_five(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.custom_script_concurrency() == 2
    store.set_custom_script_concurrency(5)
    assert ConfigStore(AppPaths(tmp_path)).custom_script_concurrency() == 5
    assert store.max_parallel() == 6

    with pytest.raises(ValueError, match="1–5"):
        store.set_custom_script_concurrency(6)


def test_legacy_window_settings_are_removed_from_config(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    store.save_config(
        {
            "schema_version": 1,
            "app": {
                "theme": "system",
                "window_width": 1200,
                "window_height": 720,
                "window_centered": False,
                "middle_panel_color": "#1B476D",
            },
        }
    )

    migrated = store.load_config()
    assert migrated["app"]["theme"] == "system"
    assert "window_width" not in migrated["app"]
    assert "window_height" not in migrated["app"]
    assert "window_centered" not in migrated["app"]
    assert "middle_panel_color" not in migrated["app"]


def test_theme_mode_defaults_validates_and_round_trips(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.theme_mode() == "system"
    store.set_theme_mode("dark")
    assert ConfigStore(AppPaths(tmp_path)).theme_mode() == "dark"

    config = store.load_config()
    config["app"]["theme"] = "unknown"
    store.save_config(config)
    assert store.theme_mode() == "system"


def test_merit_count_is_persisted_and_incremented(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.merit_count() == 0
    assert store.increment_merit_count() == 1
    assert store.increment_merit_count() == 2
    assert ConfigStore(AppPaths(tmp_path)).merit_count() == 2


def test_export_user_configuration_copies_only_local_script_entries(tmp_path: Path) -> None:
    paths = AppPaths(tmp_path / "app-data")
    store = ConfigStore(paths)
    store.load_config()
    custom_script = paths.scripts_dir / "hello.py"
    custom_script.write_text("print('hello')", encoding="utf-8")
    generated_output = paths.outputs_dir / "result.log"
    generated_output.write_text("not configuration", encoding="utf-8")

    exported = store.export_user_configuration(tmp_path / "Documents")

    assert exported.parent == tmp_path / "Documents"
    assert not (exported / "config.json").exists()
    assert (exported / "scripts" / "hello.py").read_text(encoding="utf-8") == "print('hello')"
    assert not (exported / "outputs").exists()
    assert not (exported / "logs").exists()


def test_import_user_configuration_replaces_default_directory_and_backs_up(
    tmp_path: Path,
) -> None:
    paths = AppPaths(tmp_path / "app-data")
    store = ConfigStore(paths)
    current = store.load_config()
    current["android"]["preferred_device"] = "old-device"
    store.save_config(current)
    old_script = paths.scripts_dir / "old.py"
    old_script.write_text("print('old')", encoding="utf-8")

    imported = tmp_path / "imported"
    (imported / "tools" / "custom").mkdir(parents=True)
    imported_config = {
        "schema_version": 1,
        "android": {"preferred_device": "new-device"},
    }
    (imported / "config.json").write_text(
        json.dumps(imported_config),
        encoding="utf-8",
    )
    (imported / "tools" / "custom" / "sample.json").write_text(
        "{}",
        encoding="utf-8",
    )

    backup = store.import_user_configuration(imported)

    assert store.preferred_android_device() == "old-device"
    assert (paths.custom_dir / "sample.json").is_file()
    assert not (backup / "config.json").exists()
    assert not old_script.exists()
    assert (backup / "scripts" / "old.py").read_text(encoding="utf-8") == "print('old')"
