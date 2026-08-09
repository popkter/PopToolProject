import json
from pathlib import Path

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths


def test_config_round_trip(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    config = store.load_config()
    config["app"]["last_section"] = "preset"
    store.save_config(config)
    assert store.load_config()["app"]["last_section"] == "preset"


def test_default_parallel_capacity_reserves_one_slot_for_scrcpy(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.max_parallel() == 3


def test_window_size_defaults_to_800_by_600_and_can_be_saved(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.window_size() == (800, 600)

    store.set_window_size(1200, 720)

    assert ConfigStore(AppPaths(tmp_path)).window_size() == (1200, 720)
    config = store.load_config()
    assert config["app"]["window_width"] == 1200
    assert config["app"]["window_height"] == 720


def test_window_width_is_clamped_to_responsive_layout_minimum(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    config = store.load_config()
    config["app"]["window_width"] = 600
    store.save_config(config)

    assert store.window_size() == (720, 600)
    assert store.load_config()["app"]["window_width"] == 720


def test_window_size_is_added_to_an_existing_legacy_config(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))
    store.save_config({"schema_version": 1, "app": {"theme": "system"}})

    assert store.window_size() == (800, 600)

    migrated = store.load_config()
    assert migrated["app"]["theme"] == "system"
    assert migrated["app"]["window_width"] == 800
    assert migrated["app"]["window_height"] == 600
    assert store.window_centered() is True
    assert store.load_config()["app"]["window_centered"] is True


def test_window_centering_can_be_disabled(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    store.set_window_centered(False)

    assert ConfigStore(AppPaths(tmp_path)).window_centered() is False


def test_theme_mode_defaults_validates_and_round_trips(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.theme_mode() == "system"
    store.set_theme_mode("dark")
    assert ConfigStore(AppPaths(tmp_path)).theme_mode() == "dark"

    config = store.load_config()
    config["app"]["theme"] = "unknown"
    store.save_config(config)
    assert store.theme_mode() == "system"


def test_middle_panel_color_defaults_validates_and_round_trips(tmp_path: Path) -> None:
    store = ConfigStore(AppPaths(tmp_path))

    assert store.middle_panel_color() == "#EEF7FF"
    store.set_middle_panel_color("#dceeff")
    assert ConfigStore(AppPaths(tmp_path)).middle_panel_color() == "#DCEEFF"

    store.set_middle_panel_color("#80dceeff")
    assert ConfigStore(AppPaths(tmp_path)).middle_panel_color() == "#80DCEEFF"

    config = store.load_config()
    config["app"]["middle_panel_color"] = "not-a-color"
    store.save_config(config)
    assert store.middle_panel_color() == "#EEF7FF"


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
