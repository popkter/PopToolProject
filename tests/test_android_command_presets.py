from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

from poptools.domain.models import ToolDefinition
from poptools.domain.parameter_templates import render_template
from poptools.paths import resource_path
from poptools.viewmodels.tool_list_model import ToolListModel

EXPECTED_CATEGORY_COUNTS = {
    "模拟相关": 7,
    "环境相关": 4,
    "硬件相关": 2,
    "跳转相关": 4,
    "其他设备操作": 24,
}


def _load_runner() -> ModuleType:
    path = resource_path("tools", "android_cmd_tools.py")
    spec = importlib.util.spec_from_file_location("android_cmd_tools", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _definitions() -> list[ToolDefinition]:
    path = resource_path("tools", "android-command-presets.json")
    entries = json.loads(path.read_text(encoding="utf-8"))
    return [ToolDefinition.model_validate(entry) for entry in entries]


def test_android_command_presets_cover_requested_categories() -> None:
    tools = _definitions()

    assert len(tools) == sum(EXPECTED_CATEGORY_COUNTS.values()) == 41
    assert len({tool.id for tool in tools}) == len(tools)
    for category, expected_count in EXPECTED_CATEGORY_COUNTS.items():
        assert sum(category in tool.tags for tool in tools) == expected_count


def test_every_preset_argument_is_accepted_by_runner_parser() -> None:
    module = _load_runner()
    fallback_values = {
        "text": "hello",
        "url": "https://example.com",
        "activity": "com.example/.MainActivity",
        "apk": "example.apk",
        "package": "com.example.app",
        "permission": "android.permission.CAMERA",
        "local_path": "",
        "target": "",
        "filter": "",
    }

    for tool in _definitions():
        values = {
            parameter.id: parameter.default
            if parameter.default not in (None, "")
            else fallback_values.get(parameter.id, "value")
            for parameter in tool.parameters
        }
        arguments = [render_template(argument, values) for argument in tool.executor.args]
        parsed = module.build_parser().parse_args(arguments)
        assert callable(parsed.handler), tool.id


def test_adb_args_uses_selected_device(monkeypatch) -> None:
    module = _load_runner()
    monkeypatch.setenv("POPTOOLS_ADB", str(Path("platform-tools") / "adb"))
    monkeypatch.setenv("ANDROID_SERIAL", "serial-123")

    assert module.adb_args("shell", "getprop") == [
        str(Path("platform-tools") / "adb"),
        "-s",
        "serial-123",
        "shell",
        "getprop",
    ]


def test_preset_model_filters_tools_by_category() -> None:
    model = ToolListModel()
    tools = _definitions()
    model.set_tools(tools)

    for category, expected_count in EXPECTED_CATEGORY_COUNTS.items():
        model.set_category(category)
        assert model.rowCount() == expected_count


def test_keyboard_navigation_respects_search_and_kind_filters() -> None:
    tools = _definitions()
    model = ToolListModel()
    model.set_tools(tools, selected_id=tools[0].id)
    assert model.adjacentToolId(-1, "all") == tools[0].id
    assert model.adjacentToolId(1, "all") == tools[1].id
    model.set_filter(tools[-1].title)
    assert model.adjacentToolId(1, "all") == tools[-1].id
    assert model.adjacentToolId(1, "not-an-executor") == ""
    model.set_filter("no script matches this query")
    assert model.adjacentToolId(-1, "all") == ""
