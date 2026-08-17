from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_console_panel_size_contract_is_owned_by_each_parent() -> None:
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    recent = (QML_ROOT / "components" / "RecentToolDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "property real defaultExpandedHeight" not in console
    assert "property real offsetHeight" not in console
    assert "parent ? parent.height" not in console
    assert "Math.min(640" not in console
    assert "required property int minimumVisibleLineCount" in console
    assert "readonly property real minimumExpandedHeight:" in console
    assert "required property real preferredExpandedHeight" in console
    assert "required property real maximumExpandedHeight" in console
    assert "required property bool resizable" in console
    assert "enabled: root.resizable" in console
    assert "visible: root.resizable" in console

    assert "readonly property real titleActionsBottom" in main
    assert "readonly property real parameterContentBottom" in main
    assert "contentLayout.y + topActionRow.y + topActionRow.height" in main
    assert "contentPanel.height - parameterContentBottom" in main
    assert "maximumExpandedHeight: fixedExpandedHeight" in main
    assert "resizable: workspaceLoader.hasParameters" in main

    assert "readonly property real parameterContentBottom" in recent
    assert "dialogBody.height - parameterContentBottom" in recent
    assert "maximumExpandedHeight: fixedExpandedHeight" in recent
    assert "resizable: false" in recent


def test_parameter_console_defaults_below_inputs_but_can_expand_to_title() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert (
        "preferredExpandedHeight: workspaceLoader.hasParameters\n"
        "                            ? parameterLimitedHeight : fixedExpandedHeight"
        in main
    )
    assert "maximumExpandedHeight: fixedExpandedHeight" in main

    assert "minimumVisibleLineCount: 5" in main


def test_recent_tool_console_is_fixed_and_reserves_five_output_lines() -> None:
    recent = (QML_ROOT / "components" / "RecentToolDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "minimumVisibleLineCount: 5" in recent
    assert "resizable: false" in recent
    assert "readonly property real consolePreferredHeight: 292" in recent
    assert "Math.min(root.consolePreferredHeight," in recent
    assert "parameterLimitedHeight))" in recent
    assert "maximumExpandedHeight: fixedExpandedHeight" in recent


def test_console_minimum_height_guarantees_five_visible_output_lines() -> None:
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(
        encoding="utf-8"
    )

    assert "Math.ceil(consoleFontMetrics.lineSpacing * minimumVisibleLineCount)" in console
    assert "separatorHeight + headerHeight + outputOuterMargin" in console
    assert "outputViewportMargin * 2 + outputTextVerticalPadding" in console
    assert "topPadding: root.outputTextVerticalPadding / 2" in console
    assert "bottomPadding: root.outputTextVerticalPadding / 2" in console


def test_console_cannot_be_dragged_below_its_default_height() -> None:
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(
        encoding="utf-8"
    )

    assert "readonly property real dragMinimumExpandedHeight: root.resizable" in console
    assert "Math.min(maximumExpandedHeight, preferredExpandedHeight)" in console
    assert "return Math.max(dragMinimumExpandedHeight," in console
    assert "onDragMinimumExpandedHeightChanged" in console
    assert "root.expandedHeight = root.clampedHeight(requestedHeight)" in console


def test_parameter_workspace_exposes_content_presence_and_height() -> None:
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(
        encoding="utf-8"
    )
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "readonly property int parameterCount:" in command
    assert "readonly property bool hasParameters: parameterCount > 0" in command
    assert "parameterCount * parameterItemHeight" in command
    assert "(parameterCount - 1) * parameterItemSpacing" in command
    assert "readonly property bool hasParameters:" in main
    assert "workspaceLoader.parameterContentHeight" in main


def test_parameter_controls_use_the_same_fixed_size_as_the_count_formula() -> None:
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(
        encoding="utf-8"
    )

    assert "readonly property real parameterLabelHeight: 20" in command
    assert "readonly property real parameterInputHeight: 54" in command
    assert "readonly property real parameterLabelSpacing: 6" in command
    assert "readonly property real parameterItemSpacing: 13" in command
    assert "height: root.parameterContentHeight" in command
    assert "height: root.parameterItemHeight" in command
    assert "height: root.parameterLabelHeight" in command
    assert "height: singleLineHeight" in command
