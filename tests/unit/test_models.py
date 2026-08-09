import pytest
from pydantic import ValidationError

from poptools.domain.models import ToolDefinition, ToolSection


def test_legacy_local_builtin_is_migrated_to_preset() -> None:
    tool = ToolDefinition.model_validate(
        {
            "id": "local.example",
            "section": "local",
            "title": "示例",
            "executor": {"kind": "process", "command": "adb"},
        }
    )
    assert tool.id == "local.example"
    assert tool.section == ToolSection.PRESET
    assert tool.editable is True
    assert "edited" not in tool.to_qml()
    assert "custom" not in tool.to_qml()


@pytest.mark.parametrize("tool_id", ["../config", r"..\config", "/tmp/tool", "bad id"])
def test_tool_id_cannot_escape_repository_directory(tool_id: str) -> None:
    with pytest.raises(ValidationError, match="tool id must start"):
        ToolDefinition.model_validate(
            {
                "id": tool_id,
                "section": "local",
                "title": "不安全 ID",
                "executor": {"kind": "process", "command": "adb"},
            }
        )


def test_legacy_local_custom_tool_is_migrated_to_custom() -> None:
    tool = ToolDefinition.model_validate(
        {
            "id": "custom.example",
            "origin": "custom",
            "section": "local",
            "title": "示例",
            "executor": {"kind": "powershell", "command": "echo ok"},
        }
    )

    assert tool.section == ToolSection.CUSTOM


def test_legacy_preset_tool_id_is_migrated() -> None:
    tool = ToolDefinition.model_validate(
        {
            "id": "online.json",
            "origin": "override",
            "section": "online",
            "title": "JSON",
            "executor": {"kind": "internal", "command": "json"},
        }
    )

    assert tool.id == "preset.json"
    assert tool.section == ToolSection.PRESET
