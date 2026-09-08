pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    required property var controller
    required property var androidBackend
    required property var parentWindow
    required property var parameterValues
    required property var displayedTool
    property bool consoleExpanded: false

    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal toastRequested(string message, bool error)

    radius: 10
    color: Theme.surfaceContainerLow
    border.color: Theme.darkMode ? Theme.outlineVariant : "#E0E4EA"
    border.width: 1
    clip: true

    function kindLabel() {
        if (!root.displayedTool.executor)
            return ""
        const kind = root.displayedTool.executor.kind
        return kind === "batch" ? "ADB"
            : kind === "powershell" ? "PowerShell"
            : kind === "python" ? "Python" : kind
    }

    function kindColor() {
        const kind = root.displayedTool.executor ? root.displayedTool.executor.kind : ""
        return kind === "python" ? Theme.tertiary
            : kind === "batch" ? Theme.success : Theme.primary
    }

    function kindBackground() {
        const kind = root.displayedTool.executor ? root.displayedTool.executor.kind : ""
        return kind === "python" ? Theme.tertiaryContainer
            : kind === "batch" ? Theme.successContainer : Theme.primaryContainer
    }

    function runSelectedTool() {
        if (root.controller.running) {
            root.controller.stopExecution()
        } else if (root.displayedTool.presentation
                   && root.displayedTool.presentation.confirm_before_run) {
            root.confirmRunRequested(root.parameterValues)
        } else {
            root.controller.runSelected(root.parameterValues)
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 108

        Rectangle {
            x: 23
            y: 23
            width: 46
            height: 46
            radius: 9
            color: root.kindBackground()
            MaterialIcon {
                anchors.centerIn: parent
                icon: root.displayedTool.presentation
                    ? (root.displayedTool.presentation.icon || "terminal") : "terminal"
                iconSize: 23
                color: root.kindColor()
            }
        }

        Text {
            x: 85
            y: 22
            width: parent.width - 210
            text: root.displayedTool.title || "请选择脚本"
            color: Theme.textPrimary
            font.pixelSize: 20
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            x: 85
            y: 52
            width: parent.width - 210
            text: root.displayedTool.description || "选择脚本以查看参数、运行状态和输出"
            color: Theme.textSecondary
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            x: parent.width - 101
            y: 24
            width: 77
            height: 34
            radius: 7
            color: shareMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.color: Theme.outline
            Row {
                anchors.centerIn: parent
                spacing: 7
                MaterialIcon { icon: "ios_share"; iconSize: 17; color: Theme.textSecondary }
                Text { text: "分享"; color: Theme.textPrimary; font.pixelSize: 13 }
            }
            MouseArea {
                id: shareMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const success = root.controller.exportSelectedScriptToClipboard()
                    root.toastRequested(success ? "脚本已复制到剪贴板" : "脚本分享失败", !success)
                }
            }
        }

        Rectangle {
            x: 23
            y: 88
            width: parent.width - 47
            height: 1
            color: Theme.outlineVariant
        }
    }

    Text {
        x: 23
        y: 108
        text: "参数配置"
        color: Theme.textPrimary
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    Text {
        x: 23
        y: 140
        text: "运行前确认目标设备与参数"
        color: Theme.textSecondary
        font.pixelSize: 12
    }

    Flickable {
        id: parameterArea
        x: 23
        y: 168
        width: parent.width - 47
        height: Math.max(0, actionArea.y - y - 8)
        clip: true
        contentWidth: width
        contentHeight: parameterColumn.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: parameterColumn
            width: parameterArea.width
            spacing: 8

            Repeater {
                model: root.displayedTool.parameters || []
                delegate: Column {
                    id: parameterItem
                    required property var modelData
                    width: parameterColumn.width
                    spacing: 6

                    Row {
                        width: parent.width
                        height: 20
                        Text {
                            width: parent.width - requiredLabel.width
                            text: parameterItem.modelData.label
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            id: requiredLabel
                            text: parameterItem.modelData.required ? "必填" : ""
                            color: Theme.textSecondary
                            font.pixelSize: 12
                        }
                    }

                    Loader {
                        width: parent.width
                        height: 40
                        sourceComponent: parameterItem.modelData.kind === "choice"
                            ? choiceField : parameterItem.modelData.kind === "boolean"
                            ? booleanField : textField

                        Component {
                            id: textField
                            TextField {
                                text: String(parameterItem.modelData.default || "")
                                placeholderText: parameterItem.modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: 14
                                leftPadding: 13
                                rightPadding: 13
                                echoMode: parameterItem.modelData.kind === "secret"
                                    ? TextInput.Password : TextInput.Normal
                                background: Rectangle {
                                    radius: 7
                                    color: Theme.surfaceContainerLow
                                    border.color: parent.activeFocus ? Theme.primary : "#A8CFFF"
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[parameterItem.modelData.id] = text
                            }
                        }

                        Component {
                            id: choiceField
                            AppComboBox {
                                model: parameterItem.modelData.options || []
                                textRole: count > 0 && typeof model[0] === "object" ? "label" : ""
                                leftPadding: 13
                                font.pixelSize: 14
                                onCurrentTextChanged: root.parameterValues[parameterItem.modelData.id] = currentText
                            }
                        }

                        Component {
                            id: booleanField
                            CheckBox {
                                text: parameterItem.modelData.label
                                checked: Boolean(parameterItem.modelData.default)
                                onToggled: root.parameterValues[parameterItem.modelData.id] = checked
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: parameterItem.modelData.kind !== "boolean"
                        text: parameterItem.modelData.label.indexOf("VIN") >= 0
                            ? "17 位车辆识别码，写入后将自动读取并验证。"
                            : "该值将在运行脚本时作为参数传入。"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Item { width: 1; height: 8 }
                }
            }

            Column {
                visible: !!root.displayedTool.uses_android_device
                width: parent.width
                spacing: 6
                Text {
                    text: "目标设备"
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: parent.width
                    height: 41
                    radius: 8
                    color: Theme.darkMode ? Theme.surfaceContainer : "#FAFBFC"
                    border.color: Theme.outline
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 10
                        spacing: 10
                        MaterialIcon { icon: "smartphone"; iconSize: 19; color: Theme.success }
                        Text {
                            Layout.fillWidth: true
                            text: root.androidBackend.selectedAndroidDeviceLabel
                            color: Theme.textPrimary
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                        Text {
                            text: root.androidBackend.selectedAndroidDevice.length > 0 ? "已连接" : "未连接"
                            color: root.androidBackend.selectedAndroidDevice.length > 0 ? Theme.success : Theme.textSecondary
                            font.pixelSize: 11
                        }
                        MaterialIcon { icon: "expand_more"; iconSize: 18; color: Theme.textSecondary }
                    }
                }
                Item { width: 1; height: 6 }
            }
        }
    }

    Item {
        id: actionArea
        x: 23
        y: consolePanel.y - height - 8
        width: parent.width - 47
        height: 41

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: 108
            height: 34
            radius: 7
            color: editMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.color: Theme.outline
            Text { anchors.centerIn: parent; text: "编辑脚本"; color: Theme.textPrimary; font.pixelSize: 13 }
            MouseArea {
                id: editMouse
                anchors.fill: parent
                enabled: !!root.displayedTool.editable && !root.controller.running
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.editRequested()
            }
        }


        Rectangle {
            id: runButton
            anchors.right: parent.right
            anchors.top: parent.top
            width: 152
            height: 34
            radius: 7
            color: runMouse.containsMouse ? Theme.primaryHover : Theme.primary
            Row {
                anchors.centerIn: parent
                spacing: 10
                MaterialIcon { icon: root.controller.running ? "stop" : "play_arrow"; iconSize: 18; color: "white" }
                Text { text: root.controller.running ? "停止运行" : "运行脚本"; color: "white"; font.pixelSize: 13; font.weight: Font.Medium }
            }
            MouseArea {
                id: runMouse
                anchors.fill: parent
                enabled: !!root.displayedTool.id
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.runSelectedTool()
            }
        }

        Rectangle { x: 120; anchors.top: parent.top; width: 108; height: 34; radius: 7; color: deleteMouse.containsMouse ? Theme.errorContainer : Theme.errorContainer; border.color: Theme.error
            Text { anchors.centerIn: parent; text: "删除"; color: Theme.error; font.pixelSize: 13 }
            MouseArea { id: deleteMouse; anchors.fill: parent; enabled: !!root.displayedTool.id && !root.controller.running; hoverEnabled: true; onClicked: root.deleteRequested() }
        }
        Rectangle { x: 240; anchors.top: parent.top; width: 108; height: 34; radius: 7; color: shareBottomMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow; border.color: Theme.outline
            Text { anchors.centerIn: parent; text: "分享"; color: Theme.textPrimary; font.pixelSize: 13 }
            MouseArea { id: shareBottomMouse; anchors.fill: parent; enabled: !!root.displayedTool.id; hoverEnabled: true; onClicked: { const success = root.controller.exportSelectedScriptToClipboard(); root.toastRequested(success ? "脚本已复制到剪贴板" : "脚本分享失败", !success) } }
        }
    }

    Rectangle {
        id: consolePanel
        x: 23
        width: parent.width - 47
        height: root.consoleExpanded ? Math.min(348, Math.max(42, root.height - 320)) : 42
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 23
        radius: 9
        color: Theme.consoleBackground
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 42
            radius: 8
            color: Theme.consoleHeaderBackground
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10
                Text { text: "控制台输出"; color: Theme.consoleText; font.pixelSize: 13; font.weight: Font.DemiBold }
                Item { Layout.preferredWidth: 20 }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: root.controller.running ? Theme.consoleWarning : Theme.success }
                Text { text: root.controller.running ? "运行中" : "已完成"; color: root.controller.running ? Theme.consoleWarning : Theme.success; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text {
                    text: "复制输出"
                    color: copyMouse.containsMouse ? Theme.consoleText : Theme.consoleMuted
                    font.pixelSize: 12
                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { consoleText.selectAll(); consoleText.copy(); consoleText.deselect() }
                    }
                }
                Item { Layout.preferredWidth: 28 }
                Text {
                    text: "清空"
                    color: clearMouse.containsMouse ? Theme.consoleText : Theme.consoleMuted
                    font.pixelSize: 12
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.controller.clearConsole()
                    }
                }
                ToolButton {
                    objectName: "customConsoleToggle"
                    text: root.consoleExpanded ? "收起" : "展开"
                    Accessible.name: root.consoleExpanded ? "收起控制台输出" : "展开控制台输出"
                    contentItem: Row {
                        spacing: 4
                        Text { text: root.consoleExpanded ? "收起" : "展开"; color: Theme.consoleText; font.pixelSize: 12 }
                        MaterialIcon { icon: root.consoleExpanded ? "expand_more" : "expand_less"; iconSize: 16; color: Theme.consoleText }
                    }
                    background: Rectangle { radius: 4; color: parent.hovered ? Theme.consoleBackground : "transparent" }
                    onClicked: root.consoleExpanded = !root.consoleExpanded
                }
            }
        }

        TextArea {
            id: consoleText
            visible: root.consoleExpanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 51
            anchors.bottom: footer.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: root.controller.consoleText
            readOnly: true
            selectByMouse: true
            color: Theme.consoleText
            selectionColor: Theme.primary
            font.family: "Cascadia Mono"
            font.pixelSize: 12
            background: null
        }

        Rectangle {
            id: footer
            radius: 8
            visible: root.consoleExpanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 54
            color: Theme.consoleBackground
            border.color: Theme.darkMode ? "#2A3442" : "#25303D"
            border.width: 1
            Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: "✓ 退出码 0"; color: Theme.success; font.pixelSize: 11 }
            Text { anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: root.controller.statusText; color: Theme.consoleMuted; font.pixelSize: 11 }
        }
    }
}
