from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_running_command_uses_the_primary_button_as_stop_control() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")
    button = (QML_ROOT / "components" / "PrimaryButton.qml").read_text(encoding="utf-8")

    assert "successStyle: appController.running" in main
    assert 'window.scrcpySelected ? "停止投屏" : "停止运行"' in main
    assert 'window.scrcpySelected ? "开始投屏" : "运行命令"' in main
    assert "id: scrcpyHost" in command
    assert "root.controller.updateScrcpyGeometry" in command
    assert 'iconName: appController.running ? "stop" : "play_arrow"' in main
    assert "appController.stopExecution()" in main
    assert '!window.internalPresetSelected || window.scrcpySelected' in main
    assert 'window.internalPresetSelected && !window.scrcpySelected' in main
    assert "property bool successStyle: false" in button
    assert "Theme.success" in button


def test_embedded_scrcpy_window_is_hidden_when_leaving_the_scrcpy_tool() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert "function hideScrcpyWindow()" in main
    assert "appController.updateScrcpyGeometry(0, 0, 0, 0, false)" in main
    assert "onScrcpySelectedChanged" in main
    assert "if (!scrcpySelected)" in main
    assert "onVisibleChanged" in command


def test_console_panel_does_not_duplicate_the_stop_control() -> None:
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")

    assert "stopExecution" not in console
    assert "stopMouse" not in console
    assert 'text: "停止"' not in console


def test_run_data_panel_can_be_resized_without_an_export_control() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")

    assert 'text: "运行数据"' in console
    assert "id: resizeSeparator" in console
    assert console.count("height: 20") >= 2
    assert "anchors.topMargin: 20" in console
    assert "root.expandedHeight : 82" in console
    assert "color: root.panelColor" in console
    assert "panelColor: middlePanelBackdrop.color" in main
    assert "anchors.left: parent.left" in console
    assert "anchors.right: parent.right" in console
    assert "id: resizeHandle" not in console
    assert "cursorShape: Qt.SizeVerCursor" in console
    assert "root.expandedHeight = Math.max" in console
    assert "height: implicitHeight" in main
    assert main.count("ConsolePanel {") == 1
    assert main.index("id: bottomConsolePanel") < main.index("id: primaryPanelResizeHandle")
    assert "bottomConsolePanel.height + 18" in main
    assert "id: runCommandButton" in main
    assert "contentPanel.height - contentLayout.y - topActionRow.y - runActionColumn.y" in main
    assert "runCommandButton.y - runCommandButton.height - 20" in main
    assert "id: workspaceLoader" in main
    assert "parameterContentHeight: parameterFlow.height" in command
    assert "workspaceLoader.parameterContentHeight - 20" in main
    assert "minimumExpandedHeight: 160" in main
    assert "property bool userResized: false" in console
    assert "onDefaultExpandedHeightChanged" in console
    assert "onMaximumExpandedHeightChanged" in console
    assert "root.userResized = true" in console
    assert "function onSelectedToolChanged()" in console
    assert "anchors.left: parent.left" in main
    assert "anchors.right: parent.right" in main
    assert "Item {\n    id: root" in console
    assert "border.width: 1" not in console
    assert "导出" not in console
    assert "保存" not in console

def test_light_console_background_is_distinct_from_the_main_surface() -> None:
    theme = (QML_ROOT / "theme" / "Theme.qml").read_text(encoding="utf-8")

    assert 'consoleBackground: darkMode ? "#141A20" : "#EEF3F8"' in theme
