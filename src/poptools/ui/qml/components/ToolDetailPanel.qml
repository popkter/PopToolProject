pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    required property var controller
    required property var parentWindow
    required property var parameterValues
    required property var displayedTool
    property var presetUtilities: null
    property var androidBackend: null
    property var jiraFeishuBackend: null
    property bool drawerMode: false
    property bool drawerVisible: false
    property bool compact: false
    property bool compactHeight: false
    property bool overlaysVisible: false
    property bool internalPresetSelected: false
    property bool scrcpySelected: false
    property bool recordingSelected: false
    readonly property bool operationRunning: recordingSelected
        ? presetUtilities.recording : controller.running
    readonly property real consoleContentGap: Theme.space16

    signal closeRequested()
    signal drawerClosed()
    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal toastRequested(string message, bool error)

    radius: drawerMode ? Theme.radiusLarge : Theme.radiusNone
    border.color: drawerMode ? Theme.outlineVariant : "transparent"
    border.width: drawerMode ? Theme.borderWidthThin : 0
    clip: true
    color: Theme.surface

    MouseArea {
        anchors.fill: parent
        enabled: root.drawerMode
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        onWheel: function(wheel) { wheel.accepted = true }
    }

    state: root.drawerMode
        ? (root.drawerVisible ? "drawerOpen" : "drawerClosed") : ""
    states: [
        State {
            name: "drawerOpen"
            PropertyChanges {
                root.x: root.parent.width - root.width - Theme.space12
            }
        },
        State {
            name: "drawerClosed"
            PropertyChanges { root.x: root.parent.width + Theme.space12 }
        }
    ]
    transitions: [
        Transition {
            from: "drawerClosed"
            to: "drawerOpen"
            NumberAnimation {
                property: "x"
                duration: 260
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            from: "drawerOpen"
            to: "drawerClosed"
            NumberAnimation {
                property: "x"
                duration: 220
                easing.type: Easing.InCubic
                onStopped: root.drawerClosed()
            }
        }
    ]

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.leftMargin: root.compact
            ? Theme.pagePaddingCompact : Theme.pagePadding
        anchors.rightMargin: root.compact
            ? Theme.pagePaddingCompact : Theme.pagePadding
        anchors.topMargin: root.compactHeight
            ? Theme.pagePaddingCompact : Theme.pagePadding
        anchors.bottomMargin: bottomConsolePanel.visible
            ? bottomConsolePanel.height + root.consoleContentGap
            : (root.compactHeight ? Theme.pagePaddingCompact : Theme.pagePadding)
        spacing: Theme.sectionSpacing

        RowLayout {
            id: topActionRow
            Layout.fillWidth: true
            spacing: root.compactHeight ? Theme.space8 : Theme.space12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.controlSpacing

                Text {
                    Layout.fillWidth: true
                    text: root.displayedTool.title || "请选择工具"
                    color: Theme.textPrimary
                    font.pixelSize: root.compact
                        ? Theme.fontTitleLarge : Theme.fontPageTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.compactHeight
                    text: root.displayedTool.description
                        || "这个人很懒，并没有写脚本介绍"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.WordWrap
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Theme.controlSpacing

                RowLayout {
                    id: drawerActionRow
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.space4

                    Rectangle {
                        visible: root.drawerMode
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: closeMouse.containsMouse
                            ? Qt.darker(Theme.surfaceContainerHigh, 1.06)
                            : Theme.surfaceContainerHigh
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "close"
                            iconSize: 24
                            color: Theme.textSecondary
                        }
                        AppToolTip {
                            visible: closeMouse.containsMouse
                            text: "关闭详情"
                            delay: 450
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }

                    Rectangle {
                        visible: root.drawerMode
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: shareMouse.containsMouse
                            ? Theme.secondaryContainerHover
                            : Theme.secondaryContainer
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "reply"
                            iconSize: 28
                            color: Theme.secondary
                        }
                        AppToolTip {
                            visible: shareMouse.containsMouse
                            text: "分享脚本到剪贴板"
                            delay: 450
                        }
                        MouseArea {
                            id: shareMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const success = root.controller
                                    .exportSelectedScriptToClipboard()
                                root.toastRequested(
                                    success ? "脚本已复制到剪贴板" : "脚本分享失败",
                                    !success)
                            }
                        }
                    }

                    Rectangle {
                        visible: root.drawerMode && !!root.controller.selectedTool.id
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: deleteMouse.containsMouse
                            ? Qt.darker(Theme.errorContainer, 1.08)
                            : Theme.errorContainer
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "delete"
                            iconSize: 24
                            color: Theme.errorColor
                        }
                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            enabled: !root.controller.running
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteRequested()
                        }
                    }

                    Rectangle {
                        visible: root.drawerMode && !!root.displayedTool.editable
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: editMouse.containsMouse
                            ? Theme.tertiaryContainerHover
                            : Theme.tertiaryContainer
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "edit"
                            iconSize: 24
                            color: Theme.tertiary
                        }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            enabled: !root.controller.running
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editRequested()
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.controlSpacing

                    Rectangle {
                        visible: !!root.displayedTool.executor
                            && root.displayedTool.executor.kind === "python"
                            && !!root.displayedTool.id && !root.scrcpySelected
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: height / 2
                        color: dependencyMouse.containsMouse
                            ? Theme.primaryContainer : Theme.surface
                        border.color: dependencyMouse.containsMouse
                            ? Theme.primary : Theme.outline
                        border.width: Theme.borderWidthThin
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "fact_check"
                            iconSize: 24
                            color: Theme.primary
                        }
                        AppToolTip {
                            visible: dependencyMouse.containsMouse
                            text: "检查 Python 依赖"
                            delay: 450
                        }
                        MouseArea {
                            id: dependencyMouse
                            anchors.fill: parent
                            enabled: !root.controller.running
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controller.checkSelectedPythonDependencies()
                        }
                    }

                    PrimaryButton {
                        visible: (!root.internalPresetSelected
                            || root.scrcpySelected || root.recordingSelected)
                            && !!root.displayedTool.id
                        Layout.preferredWidth: root.drawerMode
                            ? drawerActionRow.implicitWidth
                            : (root.compact ? 60 : 176)
                        Layout.preferredHeight: 48
                        compact: root.compact
                        successStyle: root.operationRunning
                        text: root.operationRunning
                            ? (root.scrcpySelected ? "停止投屏"
                                : root.recordingSelected ? "结束录制" : "停止运行")
                            : (root.scrcpySelected ? "开始投屏"
                                : root.recordingSelected ? "开始录制" : "运行命令")
                        iconName: root.operationRunning ? "stop" : "play_arrow"
                        onClicked: root.runSelectedTool()
                    }
                }
            }
        }

        Loader {
            id: workspaceLoader
            readonly property real parameterContentHeight:
                item && item.parameterContentHeight !== undefined
                    ? item.parameterContentHeight : 0
            readonly property bool hasParameters:
                item && item.hasParameters !== undefined ? item.hasParameters : false
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.visible
            sourceComponent: root.internalPresetSelected && !root.scrcpySelected
                ? presetWorkspace : commandWorkspace
            onSourceComponentChanged: {
                if (!root.scrcpySelected)
                    root.controller.updateScrcpyGeometry(0, 0, 0, 0, false)
            }
        }
    }

    ConsolePanel {
        id: bottomConsolePanel
        readonly property real titleActionsBottom:
            contentLayout.y + topActionRow.y + topActionRow.height
        readonly property real parameterContentBottom:
            contentLayout.y + workspaceLoader.y + workspaceLoader.parameterContentHeight
        readonly property real fixedExpandedHeight: Math.max(
            minimumExpandedHeight,
            root.height - titleActionsBottom - contentLayout.spacing)
        readonly property real parameterLimitedHeight: Math.max(
            minimumExpandedHeight,
            root.height - parameterContentBottom - root.consoleContentGap)
        visible: !root.internalPresetSelected && !root.scrcpySelected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
        minimumVisibleLineCount: 5
        preferredExpandedHeight: workspaceLoader.hasParameters
            ? parameterLimitedHeight : fixedExpandedHeight
        maximumExpandedHeight: fixedExpandedHeight
        resizable: workspaceLoader.hasParameters
        controller: root.controller
        panelMargin: root.drawerMode ? root.border.width : 0
    }

    Component {
        id: commandWorkspace
        CommandWorkspace {
            controller: root.controller
            parentWindow: root.parentWindow
            parameterValues: root.parameterValues
            scrcpySelected: root.scrcpySelected
            overlaysVisible: root.overlaysVisible
        }
    }

    Component {
        id: presetWorkspace
        PresetWorkspace {
            toolController: root.controller
            utilities: root.presetUtilities
            androidBackend: root.androidBackend
            jiraFeishuBackend: root.jiraFeishuBackend
            compact: root.compact
        }
    }

    function runSelectedTool() {
        if (root.recordingSelected) {
            if (root.presetUtilities.recording) {
                root.presetUtilities.stopRecording()
                if (workspaceLoader.item
                        && workspaceLoader.item.openRecordingFolderDialog)
                    workspaceLoader.item.openRecordingFolderDialog()
            } else {
                root.presetUtilities.startRecording(
                    root.androidBackend.selectedAndroidDevice)
            }
        } else if (root.controller.running) {
            root.controller.stopExecution()
        } else if (root.displayedTool.presentation
                && root.displayedTool.presentation.confirm_before_run) {
            root.confirmRunRequested(root.parameterValues)
        } else {
            root.controller.runSelected(root.parameterValues)
        }
    }
}
