import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "../theme"

Window {
    id: root
    objectName: "recentToolWindow"

    property string toolId: ""
    property var parameterValues: ({})
    property var presetUtilities
    property var deviceController
    readonly property bool presetMode: appController.selectedTool.workspace === "preset"
    readonly property bool recordingPreset: presetMode
        && appController.selectedTool.executor
        && appController.selectedTool.executor.command === "recording"
    readonly property bool operationRunning: recordingPreset
        ? presetUtilities && presetUtilities.recording
        : appController.running
    readonly property real consolePreferredHeight: 292
    readonly property real bodySpacing: 12

    readonly property color middlePanelColor: settingsController.middlePanelColor === "#EEF7FF"
        ? Theme.middlePanel : settingsController.middlePanelColor

    width: presetMode ? 720 : 680
    height: presetMode ? 560 : 600
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"

    function centerOnScreen() {
        x = Screen.virtualX + Math.round((Screen.width - width) / 2)
        y = Screen.virtualY + Math.round((Screen.height - height) / 2)
    }

    function showWithTool(tid) {
        toolId = tid
        if (tid.length > 0)
            appController.selectTool(tid)
        var values = {}
        var tool = appController.selectedTool
        var parameters = tool.parameters || []
        for (var i = 0; i < parameters.length; i++)
            values[parameters[i].id] = parameters[i].default
        parameterValues = values
        centerOnScreen()
        visible = true
        requestActivate()
    }

    function toggleRecording() {
        if (!presetUtilities || !deviceController)
            return
        if (presetUtilities.recording) {
            presetUtilities.stopRecording()
            if (workspaceLoader.item && workspaceLoader.item.openRecordingFolderDialog)
                workspaceLoader.item.openRecordingFolderDialog()
        } else {
            presetUtilities.startRecording(deviceController.selectedAndroidDevice)
        }
    }

    // ── Main content ───────────────────────────────────────
    MultiEffect {
        id: dialogShadow
        anchors.fill: contentRect
        source: contentRect
        shadowEnabled: true
        shadowBlur: 0.7
        blurMax: 24
        shadowOpacity: Theme.darkMode ? 0.72 : 0.42
        shadowColor: "#000000"
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 6
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        anchors.margins: 8
        radius: Theme.radiusLarge
        color: Theme.darkMode ? Theme.surfaceContainer : Theme.surface
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Title bar ─────────────────────────────────
            Rectangle {
                id: dialogTitleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "transparent"

                // Drag-to-move area (covers title bar, behind interactive elements)
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: titleButtons.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onPressed: root.startSystemMove()
                }

                // Title text
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.right: titleButtons.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: appController.selectedTool.title || "运行工具"
                    color: Theme.textPrimary
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                // Buttons row (right-aligned)
                Row {
                    id: titleButtons
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 4

                    // ── Custom command run button ─────────
                    Rectangle {
                        visible: !root.presetMode
                        width: 48; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 16
                        color: root.operationRunning
                            ? (runBtnMouse.containsMouse ? Qt.darker(Theme.errorColor, 1.1) : Theme.errorColor)
                            : (runBtnMouse.containsMouse ? Theme.primaryHover : Theme.primary)
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: root.operationRunning ? "stop" : "play_arrow"
                            iconSize: 24
                            color: "white"
                        }
                        MouseArea {
                            id: runBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (appController.running) {
                                    appController.stopExecution()
                                } else {
                                    appController.runSelected(root.parameterValues)
                                }
                            }
                        }
                    }

                    PrimaryButton {
                        visible: root.recordingPreset
                        width: 132
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.operationRunning ? "结束录制" : "开始录制"
                        iconName: root.operationRunning ? "stop" : "play_arrow"
                        successStyle: root.operationRunning
                        onClicked: root.toggleRecording()
                    }

                    // Minimize
                    Rectangle {
                        width: 42; height: parent.height
                        color: minimizeArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        MaterialIcon {
                            anchors.centerIn: parent; icon: "remove"; iconSize: 19; color: Theme.textPrimary
                        }
                        MouseArea {
                            id: minimizeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.showMinimized()
                        }
                    }

                    // Close
                    Rectangle {
                        width: 42; height: parent.height
                        topRightRadius: contentRect.radius
                        color: closeArea.containsMouse ? "#C42B1C" : "transparent"
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "close"
                            iconSize: 19
                            color: closeArea.containsMouse ? "white" : Theme.textPrimary
                        }
                        MouseArea {
                            id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.close()
                        }
                    }
                }
            }


            // ── Body ──────────────────────────────────────
            Item {
                id: dialogBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16

                ColumnLayout {
                    id: bodyContent
                    anchors.fill: parent
                    anchors.bottomMargin: consolePanel.visible ? consolePanel.height : 0
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: appController.selectedTool.description || ""
                        color: Theme.textSecondary
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    Loader {
                        id: workspaceLoader
                        readonly property real parameterContentHeight:
                                item && item.parameterContentHeight !== undefined
                            ? item.parameterContentHeight : 0
                        readonly property bool hasParameters:
                                item && item.hasParameters !== undefined
                            ? item.hasParameters : false
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        sourceComponent: appController.selectedTool.workspace === "preset"
                            ? presetWorkspace : commandWorkspace
                    }
                }


                // ── Console ───────────────────────────
                ConsolePanel {
                    id: consolePanel
                    readonly property real workspaceTop: bodyContent.y + workspaceLoader.y
                    readonly property real parameterContentBottom:
                        workspaceTop + workspaceLoader.parameterContentHeight
                    readonly property real fixedExpandedHeight: Math.max(
                        minimumExpandedHeight,
                        dialogBody.height - workspaceTop - root.bodySpacing)
                    readonly property real parameterLimitedHeight: Math.max(
                        minimumExpandedHeight,
                        dialogBody.height - parameterContentBottom - root.bodySpacing)
                    visible: !root.presetMode
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: visible ? Math.min(implicitHeight, parent.height) : 0
                    minimumVisibleLineCount: 5
                    preferredExpandedHeight: Math.max(
                        minimumExpandedHeight,
                        Math.min(root.consolePreferredHeight,
                                 fixedExpandedHeight,
                                 parameterLimitedHeight))
                    maximumExpandedHeight: fixedExpandedHeight
                    resizable: false
                    controller: appController
                    panelColor: root.middlePanelColor
                }
            }
        }
    }

    Component {
        id: commandWorkspace
        CommandWorkspace {
            controller: appController
            parentWindow: root
            parameterValues: root.parameterValues
            scrcpySelected: false
            overlaysVisible: false
        }
    }

    Component {
        id: presetWorkspace
        PresetWorkspace {
            toolController: appController
            utilities: root.presetUtilities
            androidController: root.deviceController
            compact: true
        }
    }
}
