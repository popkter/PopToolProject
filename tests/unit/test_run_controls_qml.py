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


def test_python_dependency_check_is_a_separate_action_before_run() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'icon: "fact_check"' in main
    assert "checkSelectedPythonDependencies()" in main
    assert 'executor.kind === "python"' in main
    assert "Layout.preferredWidth: 48" in main
    assert "Layout.preferredHeight: 48" in main
    assert "border.color: dependencyCheckMouse.containsMouse" in main


def test_embedded_scrcpy_window_is_hidden_when_leaving_the_scrcpy_tool() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert "function hideScrcpyWindow()" in main
    assert "appController.updateScrcpyGeometry(0, 0, 0, 0, false)" in main
    assert "onScrcpySelectedChanged" in main
    assert "if (!scrcpySelected)" in main
    assert "onVisibleChanged" in command


def test_scrcpy_waits_for_stable_loader_geometry_before_becoming_visible() -> None:
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(
        encoding="utf-8"
    )

    assert "property bool geometryReady: false" in command
    assert "stableGeometryFrames >= 2" in command
    assert "interval: scrcpyHost.geometryReady ? 100 : 16" in command
    assert "Component.onCompleted: hideUntilLayoutSettles()" in command


def test_recording_workspace_reads_the_injected_android_controller() -> None:
    recording = (QML_ROOT / "components" / "RecordingWorkspace.qml").read_text(
        encoding="utf-8"
    )

    assert "text: root.androidController.selectedAndroidDeviceLabel" in recording
    assert "text: androidController.selectedAndroidDeviceLabel" not in recording


def test_console_panel_does_not_duplicate_the_stop_control() -> None:
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")

    assert "stopExecution" not in console
    assert "stopMouse" not in console
    assert 'text: "停止"' not in console


def test_run_data_panel_can_be_resized_without_an_export_control() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")
    console = (QML_ROOT / "components" / "ConsolePanel.qml").read_text(encoding="utf-8")

    assert 'text: "控制台输出"' in console
    assert "id: resizeSeparator" in console
    assert "readonly property real separatorHeight: 8" in console
    assert "anchors.topMargin: root.separatorHeight" in console
    assert "root.collapsedHeight" in console
    assert "color: Theme.consoleDivider" in console
    assert "panelColor:" not in console
    assert "panelColor: Theme.middlePanel" not in main
    assert "panelMargin: contentPanel.drawerMode ? contentPanel.border.width : 0" in main
    assert "anchors.leftMargin: root.panelMargin" in console
    assert "anchors.rightMargin: root.panelMargin" in console
    assert "anchors.left: parent.left" in console
    assert "anchors.right: parent.right" in console
    assert "id: resizeHandle" not in console
    assert "cursorShape: root.resizable ? Qt.SizeVerCursor : Qt.ArrowCursor" in console
    assert "root.expandedHeight = root.clampedHeight(requestedHeight)" in console
    assert "height: implicitHeight" in main
    assert main.count("ConsolePanel {") == 1
    assert main.index("id: bottomConsolePanel") < main.index("id: primaryPanelResizeHandle")
    assert "bottomConsolePanel.height + contentPanel.consoleContentGap" in main
    assert "id: runCommandButton" in main
    assert "contentLayout.y + topActionRow.y + topActionRow.height" in main
    assert "contentPanel.height - titleActionsBottom" in main
    assert "id: workspaceLoader" in main
    assert "parameterCount * parameterItemHeight" in command
    assert "workspaceLoader.parameterContentHeight" in main
    assert "workspaceLoader.hasParameters" in main
    assert "minimumVisibleLineCount: 5" in main
    assert "property bool userResized: false" in console
    assert "onPreferredExpandedHeightChanged" in console
    assert "onMaximumExpandedHeightChanged" in console
    assert "root.userResized = true" in console
    assert "function onSelectedToolChanged()" in console
    assert "anchors.left: parent.left" in main
    assert "anchors.right: parent.right" in main
    assert "Item {\n    id: root" in console
    assert "border.width: 1" not in console
    assert "导出" not in console
    assert "保存" not in console
    assert "required property int minimumVisibleLineCount" in console
    assert "required property real preferredExpandedHeight" in console
    assert "required property real maximumExpandedHeight" in console
    assert "required property bool resizable" in console
    assert "offsetHeight" not in console
    assert "Math.min(640" not in console

def test_light_console_background_is_distinct_from_the_main_surface() -> None:
    theme = (QML_ROOT / "theme" / "Theme.qml").read_text(encoding="utf-8")

    assert 'consoleBackground: darkMode ? "#141A20" : "#EEF3F8"' in theme
