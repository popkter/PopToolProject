from __future__ import annotations

import json
import re
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
        "window_width": 800,
        "window_height": 600,
        "window_centered": True,
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
    },
}

TOOL_SORT_MODES = ("added_time", "name", "usage", "custom")
THEME_MODES = ("system", "light", "dark")
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
            return cast(
                dict[str, Any],
                json.loads(self.paths.config_file.read_text(encoding="utf-8")),
            )
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

    def window_size(self) -> tuple[int, int]:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        width = app.get("window_width", 800)
        height = app.get("window_height", 600)
        if not isinstance(width, int) or isinstance(width, bool):
            width = 1200
        if not isinstance(height, int) or isinstance(height, bool):
            height = 600
        width = max(720, min(width, 7680))
        height = max(448, min(height, 4320))
        if app.get("window_width") != width or app.get("window_height") != height:
            app["window_width"] = width
            app["window_height"] = height
            self.save_config(config)
        return width, height

    def set_window_size(self, width: int, height: int) -> None:
        if not 720 <= width <= 7680 or not 448 <= height <= 4320:
            raise ValueError("窗口宽度需为 720–7680，高度需为 448–4320")
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["window_width"] = width
        app["window_height"] = height
        self.save_config(config)

    def window_centered(self) -> bool:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        centered = app.get("window_centered", True)
        if not isinstance(centered, bool):
            centered = True
        if app.get("window_centered") is not centered:
            app["window_centered"] = centered
            self.save_config(config)
        return centered

    def set_window_centered(self, centered: bool) -> None:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["window_centered"] = centered
        self.save_config(config)

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

    def middle_panel_color(self) -> str:
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        value = app.get("middle_panel_color", "#EEF7FF")
        if (
            not isinstance(value, str)
            or re.fullmatch(r"#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})", value) is None
        ):
            value = "#EEF7FF"
        value = value.upper()
        if app.get("middle_panel_color") != value:
            app["middle_panel_color"] = value
            self.save_config(config)
        return value

    def set_middle_panel_color(self, color: str) -> None:
        value = color.strip().upper()
        if re.fullmatch(r"#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})", value) is None:
            raise ValueError("颜色需使用 #RRGGBB 或 #AARRGGBB 格式")
        config = self.load_config()
        app = config.get("app")
        if not isinstance(app, dict):
            app = {}
            config["app"] = app
        app["middle_panel_color"] = value
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
        provider = python.get("provider", "managed")
        if provider not in ("managed", "custom"):
            provider = "managed"
        custom = python.get("custom_executable")
        custom_value = str(custom) if custom else ""
        if python.get("provider") != provider or python.get("custom_executable") != (
            custom_value or None
        ):
            python["provider"] = provider
            python["custom_executable"] = custom_value or None
            self.save_config(config)
        return provider, custom_value

    def custom_python_executable(self) -> str:
        return self.python_environment()[1]

    def set_python_environment(self, provider: str, custom_executable: str = "") -> None:
        if provider not in ("managed", "custom"):
            raise ValueError("未知的 Python 环境类型")
        config = self.load_config()
        python = config.setdefault("python", {})
        python["provider"] = provider
        if provider == "custom":
            python["custom_executable"] = custom_executable or None
        else:
            python.setdefault("custom_executable", None)
        self.save_config(config)

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

        destination.mkdir(parents=True, exist_ok=True)
        for entry in current_entries:
            if entry.is_dir():
                shutil.rmtree(entry)
            else:
                entry.unlink()
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
