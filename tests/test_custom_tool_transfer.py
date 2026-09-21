from __future__ import annotations

import json
from types import SimpleNamespace
from typing import Any

import pytest
from PySide6.QtCore import QObject

from poptools.domain.models import (
    ExecutorDefinition,
    ExecutorKind,
    ParameterDefinition,
    ParameterKind,
    ToolDefinition,
    ToolOrigin,
    ToolSection,
)
from poptools.domain.parameter_templates import render_template, synchronize_parameters
from poptools.infrastructure.custom_tool_transfer import (
    TRANSFER_FORMAT,
    decode_custom_tool,
    encode_custom_tool,
)
from poptools.viewmodels import app_controller as app_controller_module
from poptools.viewmodels.app_controller import AppController


def custom_tool(**updates: object) -> ToolDefinition:
    values = {
        "id": "custom.shared-script",
        "origin": ToolOrigin.CUSTOM,
        "section": ToolSection.CUSTOM,
        "title": "共享脚本",
        "description": "测试单脚本分享",
        "executor": ExecutorDefinition(
            kind=ExecutorKind.POWERSHELL,
            command="Write-Output 'hello'",
        ),
    }
    values.update(updates)
    return ToolDefinition.model_validate(values)


def test_custom_tool_clipboard_round_trip_preserves_definition() -> None:
    source = custom_tool()

    encoded = encode_custom_tool(source)
    payload = json.loads(encoded)
    imported = decode_custom_tool(encoded)

    assert payload["format"] == TRANSFER_FORMAT
    assert imported.model_dump(mode="json") == source.model_dump(mode="json")


def test_share_removes_defaults_from_metadata_and_all_executor_templates() -> None:
    command = (
        'Var logs = ${日志目录@dir:C:/private-logs}\n'
        'pVal token = ${令牌=private-token}\n'
        'echo "${logs}" "${token}" "${文件@file:C:/private-file}" '
        '"${普通:private-text}" "${旧格式=private-legacy}" '
        '"${模式:开启=1|关闭=0}"'
    )
    source = custom_tool(
        executor=ExecutorDefinition(
            kind=ExecutorKind.POWERSHELL, command=command,
            args=["${参数:private-arg}"], cwd="${位置@dir:C:/private-cwd}",
            env={"TEST": "${环境:private-env}"},
        ),
        parameters=synchronize_parameters([command]) + [
            ParameterDefinition(id="password", label="Password", kind=ParameterKind.SECRET,
                                default="private-password"),
            ParameterDefinition(id="multi", label="Multi", kind=ParameterKind.MULTILINE,
                                default="private-multi\n{value}"),
        ],
    )
    before = source.model_dump(mode="json")
    encoded = encode_custom_tool(source)
    exported = json.loads(encoded)["tool"]
    imported = decode_custom_tool(encoded)
    assert "private-" not in encoded
    assert all("default" not in parameter for parameter in exported["parameters"])
    assert all(parameter.default == "" for parameter in imported.parameters)
    assert imported.executor.command == (
        'Var logs = ${日志目录@dir}\n'
        'pVal token = ${令牌}\n'
        'echo "${logs}" "${token}" "${文件@file}" '
        '"${普通}" "${旧格式}" "${模式:开启=1|关闭=0}"'
    )
    assert imported.executor.args == ["${参数}"]
    assert imported.executor.cwd == "${位置@dir}"
    assert imported.executor.env == {"TEST": "${环境}"}
    assert [parameter.kind for parameter in imported.parameters] == [
        parameter.kind for parameter in source.parameters
    ]
    assert imported.parameters[5].options == source.parameters[5].options
    assert source.model_dump(mode="json") == before
    assert render_template(imported.executor.command, {
        "logs": "D:/received", "token": "new-token", "文件": "new-file",
        "普通": "new-text", "旧格式": "new-legacy", "模式": "0",
    }) == 'echo "D:/received" "new-token" "new-file" "new-text" "new-legacy" "0"'


def test_import_accepts_raw_tool_json_and_normalizes_custom_metadata() -> None:
    source = custom_tool(origin=ToolOrigin.OVERRIDE, editable=False, enabled=False)

    imported = decode_custom_tool(source.model_dump_json())

    assert imported.id == source.id
    assert imported.origin == ToolOrigin.CUSTOM
    assert imported.section == ToolSection.CUSTOM
    assert imported.editable is True
    assert imported.enabled is True


@pytest.mark.parametrize(
    ("clipboard_text", "message"),
    [
        ("", "没有可导入"),
        ("not json", "不是有效"),
        ("[]", "不是单个"),
    ],
)
def test_invalid_clipboard_content_is_rejected(clipboard_text: str, message: str) -> None:
    with pytest.raises(ValueError, match=message):
        decode_custom_tool(clipboard_text)


def test_non_custom_tool_is_rejected() -> None:
    source = custom_tool(section=ToolSection.PRESET)

    with pytest.raises(ValueError, match="只能导入客制脚本"):
        decode_custom_tool(source.model_dump_json())


def test_duplicate_id_waits_for_confirmation_before_replacing(monkeypatch) -> None:
    existing = custom_tool(title="现有脚本")
    incoming = custom_tool(title="导入脚本")
    imported: list[ToolDefinition] = []

    class FakeClipboard:
        def text(self) -> str:
            return encode_custom_tool(incoming)

    class FakeApplication:
        @staticmethod
        def clipboard() -> FakeClipboard:
            return FakeClipboard()

    class FakeRegistry:
        def get(self, tool_id: str) -> ToolDefinition | None:
            return existing if tool_id == existing.id else None

        def import_custom(self, tool: ToolDefinition) -> ToolDefinition:
            imported.append(tool)
            return tool

    controller = AppController.__new__(AppController)
    QObject.__init__(controller)
    controller.registry = FakeRegistry()  # type: ignore[assignment]
    controller.execution_coordinator = SimpleNamespace(running=lambda _tool_id: False)
    controller._selected = None
    controller._pending_import_tool = None
    controller._append_console = lambda _text: None  # type: ignore[method-assign]
    controller._refresh = lambda **_kwargs: None  # type: ignore[method-assign]
    monkeypatch.setattr(app_controller_module, "QGuiApplication", FakeApplication)

    prepared: dict[str, Any] = controller.importScriptFromClipboard()

    assert prepared["status"] == "duplicate"
    assert imported == []

    confirmed: dict[str, Any] = controller.confirmScriptImportReplacement()

    assert confirmed["status"] == "replaced"
    assert imported == [incoming]


def test_new_id_is_imported_without_confirmation(monkeypatch) -> None:
    incoming = custom_tool(id="custom.new-script", title="新增脚本")
    imported: list[ToolDefinition] = []

    clipboard = SimpleNamespace(text=lambda: encode_custom_tool(incoming))
    monkeypatch.setattr(
        app_controller_module,
        "QGuiApplication",
        SimpleNamespace(clipboard=lambda: clipboard),
    )
    controller = AppController.__new__(AppController)
    QObject.__init__(controller)
    controller.registry = SimpleNamespace(  # type: ignore[assignment]
        get=lambda _tool_id: None,
        import_custom=lambda tool: imported.append(tool) or tool,
    )
    controller.execution_coordinator = SimpleNamespace(running=lambda _tool_id: False)
    controller._selected = None
    controller._pending_import_tool = None
    controller._append_console = lambda _text: None  # type: ignore[method-assign]
    controller._refresh = lambda **_kwargs: None  # type: ignore[method-assign]

    result: dict[str, Any] = controller.importScriptFromClipboard()

    assert result["status"] == "imported"
    assert imported == [incoming]
    assert controller._pending_import_tool is None
