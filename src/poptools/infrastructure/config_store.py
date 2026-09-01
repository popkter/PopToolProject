from __future__ import annotations

import json
import shutil
import time
from datetime import datetime
from pathlib import Path
from typing import Any, cast

from poptools.infrastructure.json_file_storage import JsonFileStorage
from poptools.paths import AppPaths

DEFAULT_CONFIG: dict[str, Any] = {
    "schema_version": 1,
    "app": {
        "theme": "system",
        "language": "zh-CN",
        "last_section": "custom",
        "console_expanded": True,
        "terminal_enabled": False,
        "user_guide_seen": False,
        "merit_count": 0,
        "skipped_update_version": "",
    },
    "execution": {
        "max_parallel": 3,
        "default_timeout_seconds": 300,
        "confirm_untrusted_commands": True,
    },
    "android": {"preferred_device": None, "adb_source": "bundled"},
    "bash": {"provider": "auto", "custom_executable": None},
    "python": {"provider": "managed", "custom_executable": None},
    "custom_tools": {
        "sort_mode": "added_time",
        "order": [],
        "added_at": {},
        "usage_count": {},
        "recent_tools": [],
    },
}

TOOL_SORT_MODES = ("added_time", "name", "usage", "custom")
THEME_MODES = ("system", "light", "dark")
THEME_STYLES = ("material3", "winxp", "mario")
LOCAL_SCRIPT_ENTRIES = ("tools", "scripts")


class ConfigStore:
    """JSON adapter for small application settings only.

    Tool persistence is intentionally separated into ToolRepository so it can
    migrate to SQLite without changing this settings format.
    """

    def __init__(self, paths: AppPaths) -> None:
        self.paths = paths
        self.paths.ensure()
        self.files = JsonFileStorage(paths.backups_dir)

    def load_config(self) -> dict[str, Any]:
        if not self.paths.config_file.exists():
            self.save_config(DEFAULT_CONFIG)
            return self._copy_default()
        try:
            config = cast(
                dict[str, Any],
                json.loads(self.paths.config_file.read_text(encoding="utf-8")),
            )
            app = config.get("app")
            if isinstance(app, dict):
                changed = False
                for key in (
                    "window_width",
                    "window_height",
                    "window_centered",
                    "middle_panel_color",
                ):
                    if key in app:
                        app.pop(key)
                        changed = True
                if changed:
                    self.save_config(config)
            return config
        except (OSError, json.JSONDecodeError):
            self.files.backup(self.paths.config_file, suffix="corrupt")
            self.save_config(DEFAULT_CONFIG)
            return self._copy_default()

    def save_config(self, value: dict[str, Any]) -> None:
        self.files.write(self.paths.config_file, value)

    def max_parallel(self) -> int:
        config = self.load_config()
        execution = config.get("execution")
        if not isinstance(execution, dict):
            execution = {}
            config["execution"] = execution
        value = execution.get("max_parallel", 3)
        if not isinstance(value, int) or isinstance(value, bool):
            value = 3
        value = max(2, min(value, 64))
        if execution.get("max_parallel") != value:
            execution["max_parallel"] = value
            self.save_config(config)
        return value

    def preferred_android_device(self) -> str:
        config = self.load_config()
        value = config.get("android", {}).get("preferred_device")
        return str(value) if value else ""

    def set_preferred_android_device(self, serial: str) -> None:
        config = self.load_config()
        android = config.setdefault("android", {})
        android["preferred_device"] = serial or None
        self.save_config(config)

    def user_guide_seen(self) -> bool:
        config = self.load_config()
        app = config.get("app")
        return bool(app.get("user_guide_seen", False)) if isinstance(app, dict) else False

    def set_user_guide_seen(self, seen: bool = True) -> None:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["user_guide_seen"] = bool(seen)
        self.save_config(config)

    def skipped_update_version(self) -> str:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            return ""
        value = app.get("skipped_update_version", "")
        return str(value).strip() if isinstance(value, str) else ""

    def set_skipped_update_version(self, version: str) -> None:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["skipped_update_version"] = version.strip()
        self.save_config(config)

    def terminal_enabled(self) -> bool:
        config = self.load_config()
        app = config.get("app")
        return bool(app.get("terminal_enabled", False)) if isinstance(app, dict) else False

    def set_terminal_enabled(self, enabled: bool) -> None:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["terminal_enabled"] = bool(enabled)
        self.save_config(config)

    def merit_count(self) -> int:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        value = app.get("merit_count", 0)
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            value = 0
        if app.get("merit_count") != value:
            app["merit_count"] = value
            self.save_config(config)
        return value

    def custom_script_concurrency(self) -> int:
        config = self.load_config()
        execution = config.get("execution")
        if not isinstance(execution, dict):
            execution = {}
            config["execution"] = execution
        value = execution.get("custom_script_concurrency")
        if not isinstance(value, int) or isinstance(value, bool):
            legacy_total = execution.get("max_parallel", 3)
            if not isinstance(legacy_total, int) or isinstance(legacy_total, bool):
                legacy_total = 3
            value = legacy_total - 1
        value = max(1, min(value, 5))
        if execution.get("custom_script_concurrency") != value:
            execution["custom_script_concurrency"] = value
            self.save_config(config)
        return value

    def set_custom_script_concurrency(self, value: int) -> None:
        if not 1 <= value <= 5:
            raise ValueError("客制脚本同时运行数需为 1–5")
        config = self.load_config()
        execution = config.get("execution")
        if not isinstance(execution, dict):
            execution = {}
            config["execution"] = execution
        execution["custom_script_concurrency"] = value
        execution["max_parallel"] = value + 1
        self.save_config(config)

    def increment_merit_count(self) -> int:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        current = app.get("merit_count", 0)
        if not isinstance(current, int) or isinstance(current, bool) or current < 0:
            current = 0
        value = current + 1
        app["merit_count"] = value
        self.save_config(config)
        return value

    def theme_mode(self) -> str:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        value = app.get("theme", "system")
        if value not in THEME_MODES:
            value = "system"
        if app.get("theme") != value:
            app["theme"] = value
            self.save_config(config)
        return str(value)

    def set_theme_mode(self, mode: str) -> None:
        if mode not in THEME_MODES:
            raise ValueError("未知的界面主题")
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["theme"] = mode
        self.save_config(config)

    def theme_style(self) -> str:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        value = app.get("theme_style", "material3")
        if value not in THEME_STYLES:
            value = "material3"
        if app.get("theme_style") != value:
            app["theme_style"] = value
            self.save_config(config)
        return str(value)

    def set_theme_style(self, style: str) -> None:
        if style not in THEME_STYLES:
            raise ValueError("未知的主题风格")
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["theme_style"] = style
        self.save_config(config)

    def tool_sort_mode(self) -> str:
        config, settings = self._custom_tool_settings()
        value = settings.get("sort_mode", "added_time")
        if value not in TOOL_SORT_MODES:
            value = "added_time"
        if settings.get("sort_mode") != value:
            settings["sort_mode"] = value
            self.save_config(config)
        return str(value)

    def set_tool_sort_mode(self, mode: str) -> None:
        if mode not in TOOL_SORT_MODES:
            raise ValueError("未知的脚本排序方式")
        config, settings = self._custom_tool_settings()
        settings["sort_mode"] = mode
        self.save_config(config)

    def tool_order(self) -> list[str]:
        config, settings = self._custom_tool_settings()
        raw = settings.get("order", [])
        value = [item for item in raw if isinstance(item, str)] if isinstance(raw, list) else []
        value = list(dict.fromkeys(value))
        if raw != value:
            settings["order"] = value
            self.save_config(config)
        return value

    def set_tool_order(self, tool_ids: list[str]) -> None:
        config, settings = self._custom_tool_settings()
        settings["order"] = list(dict.fromkeys(tool_ids))
        self.save_config(config)

    def tool_added_times(self, tool_ids: list[str]) -> dict[str, float]:
        config, settings = self._custom_tool_settings()
        raw = settings.get("added_at")
        values = dict(raw) if isinstance(raw, dict) else {}
        changed = not isinstance(raw, dict)
        now = time.time()
        for offset, tool_id in enumerate(tool_ids):
            value = values.get(tool_id)
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                values[tool_id] = self._tool_file_timestamp(tool_id, now + offset * 0.000001)
                changed = True
        if changed:
            settings["added_at"] = values
            self.save_config(config)
        return {tool_id: float(values[tool_id]) for tool_id in tool_ids}

    def tool_usage_counts(self) -> dict[str, int]:
        config, settings = self._custom_tool_settings()
        raw = settings.get("usage_count")
        source = raw if isinstance(raw, dict) else {}
        values = {
            str(tool_id): count
            for tool_id, count in source.items()
            if isinstance(tool_id, str)
            and isinstance(count, int)
            and not isinstance(count, bool)
            and count >= 0
        }
        if raw != values:
            settings["usage_count"] = values
            self.save_config(config)
        return values

    def increment_tool_usage(self, tool_id: str) -> int:
        config, settings = self._custom_tool_settings()
        raw = settings.get("usage_count")
        values = dict(raw) if isinstance(raw, dict) else {}
        current = values.get(tool_id, 0)
        if not isinstance(current, int) or isinstance(current, bool) or current < 0:
            current = 0
        values[tool_id] = current + 1
        settings["usage_count"] = values
        self.save_config(config)
        return current + 1

    def record_tool_recent(self, tool_id: str) -> None:
        config, settings = self._custom_tool_settings()
        raw = settings.get("recent_tools")
        items = list(raw) if isinstance(raw, list) else []
        items = [item for item in items if isinstance(item, str)]
        if tool_id in items:
            items.remove(tool_id)
        items.insert(0, tool_id)
        items = items[:10]
        settings["recent_tools"] = items
        self.save_config(config)

    def recent_tools(self) -> list[str]:
        config, settings = self._custom_tool_settings()
        raw = settings.get("recent_tools")
        items = [item for item in raw if isinstance(item, str)] if isinstance(raw, list) else []
        return items[:10]

    def _custom_tool_settings(self) -> tuple[dict[str, Any], dict[str, Any]]:
        config = self.load_config()
        settings = config.get("custom_tools")
        if not isinstance(settings, dict):
            settings = {}
            config["custom_tools"] = settings
        return config, settings

    def _tool_file_timestamp(self, tool_id: str, fallback: float) -> float:
        for directory in (self.paths.custom_dir, self.paths.overrides_dir):
            source = directory / f"{tool_id}.json"
            try:
                if source.is_file():
                    return source.stat().st_mtime
            except OSError:
                pass
        return fallback

    def python_environment(self) -> tuple[str, str]:
        config = self.load_config()
        python = config.get("python")
        if not isinstance(python, dict):
            python = {}
            config["python"] = python
        # Python scripts always use the application-managed environment.
        # Normalize legacy custom-provider settings during read so upgrades
        # cannot continue pointing scripts at a removed interpreter.
        if python.get("provider") != "managed" or python.get("custom_executable") is not None:
            python["provider"] = "managed"
            python["custom_executable"] = None
            self.save_config(config)
        return "managed", ""

    @staticmethod
    def _copy_default() -> dict[str, Any]:
        return cast(dict[str, Any], json.loads(json.dumps(DEFAULT_CONFIG)))

    def import_user_configuration(self, source_directory: Path) -> Path:
        source = source_directory.resolve()
        destination = self.paths.data_dir.resolve()
        self._validate_transfer_source(source, destination)
        entries = self._configuration_entries(source)
        if not entries:
            raise ValueError("所选目录不包含 PopTools 本地脚本")

        backup = self.paths.backups_dir / (
            "import-before-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        )
        current_entries = self._configuration_entries(destination)
        if current_entries:
            backup.mkdir(parents=True, exist_ok=False)
            for entry in current_entries:
                self._copy_entry(entry, backup / entry.name)

        # Import is additive: retain current tools/scripts and merge the selected
        # export into them. Files with the same relative path are updated from the
        # import, while unrelated local entries remain in place and recoverable in
        # the pre-import backup above.
        destination.mkdir(parents=True, exist_ok=True)
        for entry in entries:
            self._copy_entry(entry, destination / entry.name)
        return backup

    def export_user_configuration(self, documents_directory: Path) -> Path:
        source = self.paths.data_dir.resolve()
        entries = self._configuration_entries(source)
        if not entries:
            self.load_config()
            entries = self._configuration_entries(source)

        documents = documents_directory.resolve()
        documents.mkdir(parents=True, exist_ok=True)
        destination = documents / (
            "PopTools本地脚本-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        )
        destination.mkdir(parents=False, exist_ok=False)
        for entry in entries:
            self._copy_entry(entry, destination / entry.name)
        return destination

    @staticmethod
    def _configuration_entries(directory: Path) -> list[Path]:
        return [directory / name for name in LOCAL_SCRIPT_ENTRIES if (directory / name).exists()]

    @staticmethod
    def _validate_transfer_source(source: Path, destination: Path) -> None:
        if not source.is_dir():
            raise ValueError("请选择有效的本地脚本目录")
        if source == destination or source in destination.parents or destination in source.parents:
            raise ValueError("导入目录不能与应用本地脚本目录相同或互相包含")

    @staticmethod
    def _copy_entry(source: Path, destination: Path) -> None:
        if source.is_dir():
            shutil.copytree(source, destination, dirs_exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
