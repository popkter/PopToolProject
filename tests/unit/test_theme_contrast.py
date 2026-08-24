from __future__ import annotations

import re
from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def _theme_colors() -> dict[str, tuple[str, str]]:
    source = (QML_ROOT / "theme" / "Theme.qml").read_text(encoding="utf-8")
    return {
        name: (dark, light)
        for name, dark, light in re.findall(
            r'readonly property color (\w+): darkMode \? "(#[0-9A-Fa-f]{6})"'
            r' : "(#[0-9A-Fa-f]{6})"',
            source,
        )
    }


def _luminance(value: str) -> float:
    channels = [int(value[index : index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [
        channel / 12.92
        if channel <= 0.04045
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in channels
    ]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def _contrast(first: str, second: str) -> float:
    high, low = sorted((_luminance(first), _luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def test_primary_and_success_buttons_meet_normal_text_contrast() -> None:
    colors = _theme_colors()

    for mode in (0, 1):
        assert _contrast(colors["primary"][mode], colors["primaryForeground"][mode]) >= 4.5
        assert _contrast(colors["success"][mode], colors["successForeground"][mode]) >= 4.5


def test_raw_text_and_icons_use_theme_foregrounds() -> None:
    preset = (QML_ROOT / "components" / "PresetWorkspace.qml").read_text(
        encoding="utf-8"
    )
    confirm = (QML_ROOT / "components" / "ConfirmRunDialog.qml").read_text(
        encoding="utf-8"
    )
    delete = (QML_ROOT / "components" / "DeleteToolDialog.qml").read_text(
        encoding="utf-8"
    )
    icon = (QML_ROOT / "components" / "MaterialIcon.qml").read_text(encoding="utf-8")

    assert preset.count("color: Theme.textPrimary") >= 6
    assert 'text: "确认运行此功能？"\n            color: Theme.textPrimary' in confirm
    assert 'text: "删除客制命令？"\n            color: Theme.textPrimary' in delete
    assert "color: Theme.textPrimary" in icon


def test_console_separator_uses_its_own_theme_color() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")
    theme = (QML_ROOT / "theme" / "Theme.qml").read_text(encoding="utf-8")

    assert 'readonly property color consoleDivider: darkMode ? "#ba0101" : "#e80000"' in theme
    assert "panelColor: Theme.middlePanel" not in main
    assert "property color panelColor" not in console
    assert "color: Theme.consoleDivider" in console


def test_preset_middle_panel_uses_theme_foregrounds() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    item = (QML_ROOT / "components" / "ToolListItem.qml").read_text(encoding="utf-8")
    sort_button = (QML_ROOT / "components" / "ToolSortButton.qml").read_text(
        encoding="utf-8"
    )

    assert "middlePanelForeground" not in main
    assert "function contrastingForeground(background)" not in main
    assert main.count("foregroundColor: Theme.textPrimary") >= 2
    assert "color: Theme.textPrimary" in main
    assert "property color foregroundColor" in item
    assert "root.selected ? Theme.primary : root.foregroundColor" in item
    assert "property color foregroundColor" in sort_button
    assert "color: root.foregroundColor" in sort_button
