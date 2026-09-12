pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    objectName: "customToolDetailPanel"

    required property var controller
    required property var androidBackend
    required property var parentWindow
    required property var parameterValues
    required property var displayedTool
    property bool consoleExpanded: false
    property bool allowManagement: true
    property bool externalRun: false
    readonly property bool narrowManagementLayout: allowManagement && width < 440
    readonly property bool compactHeaderActions: width < 440
    readonly property bool compactConsoleActions: consolePanel.width < 458
    readonly property bool showConsoleStatusText: !compactConsoleActions
        || consolePanel.width >= 280

    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal runRequested()
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
        if (root.externalRun) {
            root.runRequested()
            return
        }
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
            width: root.allowManagement
                ? Math.max(0, shareButton.x - x - 12)
                : Math.max(0, parent.width - x - 23)
            text: root.displayedTool.title || "请选择脚本"
            color: Theme.textPrimary
            font.pixelSize: 20
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            x: 85
            y: 52
            width: root.allowManagement
                ? Math.max(0, shareButton.x - x - 12)
                : Math.max(0, parent.width - x - 23)
            text: root.displayedTool.description || "选择脚本以查看参数、运行状态和输出"
            color: Theme.textSecondary
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        PrimaryButton {
            id: shareButton
            objectName: "customShareButton"
            visible: root.allowManagement
            x: parent.width - width - 23
            y: 24
            width: root.compactHeaderActions ? 34 : 77
            height: 34
            radius: 7
            text: "分享"
            iconName: "file_upload"
            compact: root.compactHeaderActions
            Accessible.name: "分享脚本"
            ToolTip.visible: compact && hovered
            ToolTip.text: text
            ToolTip.delay: 450
            tonal: true
            color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.color: Theme.outline
            foregroundColor: Theme.textPrimary
            labelFontSize: 13
            labelFontWeight: Font.Normal
            glyphSize: 17
            contentSpacing: 7
            onClicked: {
                const success = root.controller.exportSelectedScriptToClipboard()
                root.toastRequested(success ? "脚本已复制到剪贴板" : "脚本分享失败", !success)
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
        acceptedButtons: Qt.NoButton

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
                                id: parameterTextField
                                text: String(parameterItem.modelData.default || "")
                                placeholderText: parameterItem.modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: 14
                                leftPadding: 13
                                rightPadding: parameterItem.modelData.kind === "file" ? 45 : 13
                                echoMode: parameterItem.modelData.kind === "secret"
                                    ? TextInput.Password : TextInput.Normal
                                background: Rectangle {
                                    radius: 7
                                    color: Theme.surfaceContainerLow
                                    border.color: parent.activeFocus ? Theme.primary : "#A8CFFF"
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[parameterItem.modelData.id] = text
                                FilePathDropArea { target: parameterTextField }
                                AppTextEditMenu { target: parameterTextField }

                                PrimaryButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parameterItem.modelData.kind === "file"
                                    width: 30
                                    height: 30
                                    compact: true
                                    text: "选择文件"
                                    iconName: "folder_open"
                                    glyphSize: 19
                                    tonal: true
                                    foregroundColor: Theme.primaryText
                                    border.width: 0
                                    radius: 6
                                    // Above AppTextEditMenu's input-event overlay (z: 200).
                                    z: 201
                                    color: hovered
                                        ? Theme.primaryContainerHover
                                        : Theme.primaryContainer
                                    onClicked: {
                                        const selectedPath = root.controller.chooseParameterFile(
                                            parameterTextField.text)
                                        if (selectedPath.length > 0) {
                                            parameterTextField.text = selectedPath
                                            parameterTextField.forceActiveFocus()
                                        }
                                    }
                                }
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
        objectName: "customActionArea"
        x: 23
        y: consolePanel.y - height - 8
        width: parent.width - 47
        height: root.narrowManagementLayout ? 80 : 41

        PrimaryButton {
            id: editButton
            objectName: "customEditButton"
            visible: root.allowManagement
            x: 0
            y: 0
            width: root.narrowManagementLayout ? (parent.width - 8) / 2 : 108
            height: 36
            radius: 7
            text: "编辑脚本"
            iconName: "edit"
            tonal: true
            color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.color: Theme.outline
            foregroundColor: Theme.textPrimary
            labelFontSize: 13
            labelFontWeight: Font.Normal
            glyphSize: 18
            contentSpacing: 7
            enabled: !!root.displayedTool.editable && !root.controller.running
            onClicked: root.editRequested()
        }


        PrimaryButton {
            id: runButton
            objectName: "customRunButton"
            x: root.narrowManagementLayout ? 0 : parent.width - width
            y: root.narrowManagementLayout ? 44 : 0
            width: root.narrowManagementLayout ? parent.width : 152
            height: 36
            radius: 7
            text: root.controller.running ? "停止运行" : "运行脚本"
            iconName: root.controller.running ? "stop" : "play_arrow"
            tonal: true
            color: hovered ? Theme.primaryHover : Theme.primary
            border.width: 0
            foregroundColor: "white"
            labelFontSize: 13
            labelFontWeight: Font.Medium
            glyphSize: 18
            contentSpacing: 10
            enabled: !!root.displayedTool.id
            onClicked: root.runSelectedTool()
        }

        PrimaryButton { objectName: "customDeleteButton"; visible: root.allowManagement; x: root.narrowManagementLayout ? (parent.width + 8) / 2 : 120; y: 0; width: root.narrowManagementLayout ? (parent.width - 8) / 2 : 108; height: 36; radius: 7; tonal: true; color: Theme.errorContainer; border.color: Theme.errorColor
            text: "删除"; iconName: "delete"; foregroundColor: Theme.errorColor; labelFontSize: 13; labelFontWeight: Font.Normal; glyphSize: 18; contentSpacing: 7
            enabled: !!root.displayedTool.id && !root.controller.running; onClicked: root.deleteRequested()
        }
    }

    Rectangle {
        id: consolePanel
        objectName: "customConsolePanel"
        x: 23
        width: parent.width - 47
        height: root.consoleExpanded ? Math.min(348, Math.max(42, root.height - 320)) : 42
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 23
        radius: 9
        color: Theme.consoleBackground
        clip: true

        function scrollConsoleToBottom() {
            if (!root.consoleExpanded || !consoleScroll.contentItem)
                return

            var flickable = consoleScroll.contentItem
            flickable.contentY = Math.max(0, flickable.contentHeight - flickable.height)
        }

        onHeightChanged: Qt.callLater(scrollConsoleToBottom)

        Behavior on height {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 42
            radius: 8
            color: Theme.consoleHeaderBackground
            RowLayout {
                objectName: "customConsoleHeader"
                anchors.fill: parent
                anchors.leftMargin: root.compactConsoleActions ? 12 : 15
                anchors.rightMargin: root.compactConsoleActions ? 12 : 15
                spacing: root.compactConsoleActions ? 6 : 10
                Text { text: "控制台输出"; color: Theme.consoleText; font.pixelSize: 13; font.weight: Font.DemiBold }
                Item { visible: !root.compactConsoleActions; Layout.preferredWidth: 20 }
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: root.controller.running ? Theme.consoleWarning : Theme.success
                    Accessible.name: root.controller.running ? "运行中" : "已完成"
                }
                Text {
                    visible: root.showConsoleStatusText
                    text: root.controller.running ? "运行中" : "已完成"
                    color: root.controller.running ? Theme.consoleWarning : Theme.success
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                PrimaryButton {
                    objectName: "customConsoleCopyButton"
                    implicitWidth: root.compactConsoleActions ? 30 : 82
                    implicitHeight: 30
                    radius: 4
                    text: "复制输出"
                    iconName: "content_copy"
                    compact: root.compactConsoleActions
                    Accessible.name: "复制控制台输出"
                    ToolTip.visible: compact && hovered
                    ToolTip.text: text
                    ToolTip.delay: 450
                    tonal: true
                    color: "transparent"
                    border.width: 0
                    foregroundColor: hovered ? Theme.consoleText : Theme.consoleMuted
                    labelFontSize: 12
                    labelFontWeight: Font.Normal
                    glyphSize: 15
                    contentSpacing: 4
                    onClicked: { consoleText.selectAll(); consoleText.copy(); consoleText.deselect() }
                }
                Item { visible: !root.compactConsoleActions; Layout.preferredWidth: 8 }
                PrimaryButton {
                    objectName: "customConsoleClearButton"
                    implicitWidth: root.compactConsoleActions ? 30 : 62
                    implicitHeight: 30
                    radius: 4
                    text: "清空"
                    iconName: "delete_sweep"
                    compact: root.compactConsoleActions
                    Accessible.name: "清空控制台输出"
                    ToolTip.visible: compact && hovered
                    ToolTip.text: text
                    ToolTip.delay: 450
                    tonal: true
                    color: "transparent"
                    border.width: 0
                    foregroundColor: hovered ? Theme.consoleText : Theme.consoleMuted
                    labelFontSize: 12
                    labelFontWeight: Font.Normal
                    glyphSize: 15
                    contentSpacing: 4
                    onClicked: root.controller.clearConsole()
                }
                PrimaryButton {
                    objectName: "customConsoleToggle"
                    implicitWidth: root.compactConsoleActions ? 30 : 66
                    implicitHeight: 30
                    radius: 4
                    text: root.consoleExpanded ? "收起" : "展开"
                    iconName: root.consoleExpanded ? "expand_more" : "expand_less"
                    compact: root.compactConsoleActions
                    Accessible.name: root.consoleExpanded ? "收起控制台输出" : "展开控制台输出"
                    ToolTip.visible: compact && hovered
                    ToolTip.text: text
                    ToolTip.delay: 450
                    tonal: true
                    color: hovered ? Theme.consoleBackground : "transparent"
                    border.width: 0
                    foregroundColor: Theme.consoleText
                    labelFontSize: 12
                    labelFontWeight: Font.Normal
                    glyphSize: 16
                    contentSpacing: 4
                    onClicked: root.consoleExpanded = !root.consoleExpanded
                }
            }
        }

        Connections {
            target: root
            function onConsoleExpandedChanged() {
                Qt.callLater(consolePanel.scrollConsoleToBottom)
            }
        }

        DesktopScrollView {
            id: consoleScroll
            objectName: "customConsoleScroll"
            visible: consolePanel.height > 43
            opacity: root.consoleExpanded ? 1 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 51
            anchors.bottom: footer.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            TextArea {
                id: consoleText
                width: consoleScroll.availableWidth
                text: root.controller.consoleText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                color: Theme.consoleText
                selectionColor: Theme.primary
                selectedTextColor: "white"
                font.family: "Cascadia Mono"
                font.pixelSize: 12
                background: null
                AppTextEditMenu { target: consoleText }
                onTextChanged: Qt.callLater(consolePanel.scrollConsoleToBottom)
                onContentHeightChanged: Qt.callLater(consolePanel.scrollConsoleToBottom)
            }
        }

        Rectangle {
            id: footer
            radius: 8
            visible: consolePanel.height > 43
            opacity: root.consoleExpanded ? 1 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 54
            color: Theme.consoleBackground
            border.color: Theme.darkMode ? "#2A3442" : "#25303D"
            border.width: 1
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: "✓ 退出码 0"; color: Theme.success; font.pixelSize: 11 }
            Text { anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: root.controller.statusText; color: Theme.consoleMuted; font.pixelSize: 11 }
        }
    }

}
