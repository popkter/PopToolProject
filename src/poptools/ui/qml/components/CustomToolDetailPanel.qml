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
    property bool consoleExpanded: true
    property bool allowManagement: true
    property bool externalRun: false
    readonly property bool narrowManagementLayout: allowManagement && width < Theme.detailCompactWidth
    readonly property bool compactHeaderActions: width < Theme.detailCompactWidth
    readonly property bool compactConsoleActions: consolePanel.width < 458
    readonly property bool showConsoleStatusText: !compactConsoleActions
        || consolePanel.width >= 280
    readonly property color consoleStatusColor: controller.running ? Theme.consoleWarning
        : controller.statusText === "执行成功" ? Theme.success
        : controller.statusText.indexOf("执行失败") === 0 ? Theme.consoleError
        : Theme.consoleMuted

    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal runRequested()
    signal toastRequested(string message, bool error)

    radius: Theme.radiusMedium
    color: Theme.surfaceContainerLow
    border.color: Theme.outlineVariant
    border.width: 1
    clip: true

    component ParameterDefaultButton: PrimaryButton {
        enabled: !root.controller.running
        width: 30
        height: 30
        compact: true
        text: "设为默认值"
        iconName: "save"
        glyphSize: 19
        tonal: true
        foregroundColor: Theme.primaryText
        border.width: 0
        radius: Theme.radiusControl
        // Keep the button above the text edit menu's input overlay.
        z: 201
        color: hovered ? Theme.primaryContainerHover : Theme.runtimeBadge
    }

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
            : kind === "batch" ? Theme.success : Theme.runtimeBadgeText
    }

    function kindBackground() {
        const kind = root.displayedTool.executor ? root.displayedTool.executor.kind : ""
        return kind === "python" ? Theme.tertiaryContainer
            : kind === "batch" ? Theme.successContainer : Theme.runtimeBadge
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
        height: Math.max(130, headingRow.implicitHeight + Theme.detailPanelPadding * 2)

        RowLayout {
            id: headingRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.detailPanelPadding
            spacing: Theme.space16

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusMedium
                color: root.kindBackground()
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.displayedTool.presentation
                        ? (root.displayedTool.presentation.icon || "terminal") : "terminal"
                    iconSize: Theme.iconLarge
                    color: root.kindColor()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Theme.space4
                Text {
                    Layout.fillWidth: true
                    text: root.displayedTool.title || "请选择脚本"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontDetailTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.displayedTool.description || "选择脚本以查看参数、运行状态和输出"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.topMargin: 6
                    spacing: Theme.space12
                    Rectangle {
                        implicitWidth: 98; implicitHeight: 22; radius: Theme.radiusTiny
                        color: root.kindBackground()
                        Text { anchors.centerIn: parent; text: root.kindLabel(); color: root.kindColor(); font.pixelSize: Theme.fontSmall }
                    }
                    Text { text: "脚本"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                }
            }

            PrimaryButton {
                id: shareButton
                objectName: "customShareButton"
                visible: root.allowManagement
                Layout.preferredHeight: Theme.controlHeightSmall
                text: "分享"
                iconName: root.compactHeaderActions ? "file_upload" : ""
                Layout.preferredWidth: root.compactHeaderActions ? 36 : 78
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 6
                compact: root.compactHeaderActions
                Accessible.name: "分享脚本"
                tonal: true
                color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
                border.color: Theme.outline
                foregroundColor: Theme.textPrimary
                labelFontSize: Theme.fontSupporting
                labelFontWeight: Font.Normal
                glyphSize: Theme.iconSmall
                onClicked: {
                    const success = root.controller.exportSelectedScriptToClipboard()
                    root.toastRequested(success ? "脚本已复制到剪贴板" : "脚本分享失败", !success)
                }
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.detailPanelPadding
            anchors.rightMargin: Theme.detailPanelPadding
            height: Theme.borderWidthThin
            color: Theme.outlineVariant
        }
    }

    Text {
        id: parameterHeading
        anchors.left: parent.left
        anchors.leftMargin: Theme.detailPanelPadding
        anchors.top: header.bottom
        anchors.topMargin: Theme.space16
        text: "参数配置"
        color: Theme.textPrimary
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Text {
        id: parameterDescription
        anchors.left: parameterHeading.left
        anchors.top: parameterHeading.bottom
        anchors.topMargin: Theme.space8
        text: "运行前确认目标设备与参数"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontCaption
    }

    Flickable {
        id: parameterArea
        x: Theme.detailPanelPadding
        anchors.top: parameterDescription.bottom
        anchors.topMargin: Theme.space12
        width: parent.width - Theme.detailPanelPadding * 2
        height: Math.max(0, actionArea.y - y - Theme.space8)
        clip: true
        contentWidth: width
        contentHeight: parameterColumn.height
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: parameterColumn
            width: parameterArea.width
            spacing: Theme.space8

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
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                        }
                        Text {
                            id: requiredLabel
                            text: parameterItem.modelData.required ? "必填" : ""
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontCaption
                        }
                    }

                    Loader {
                        width: parent.width
                        height: parameterItem.modelData.kind === "multiline" ? 88 : Theme.inputHeight
                        sourceComponent: parameterItem.modelData.kind === "choice"
                            ? choiceField : parameterItem.modelData.kind === "boolean"
                            ? booleanField : parameterItem.modelData.kind === "multiline"
                            ? multilineField : textField

                        Component {
                            id: textField
                            AppTextField {
                                id: parameterTextField
                                readonly property bool pathPickerVisible:
                                    parameterItem.modelData.kind === "file"
                                    || parameterItem.modelData.kind === "directory"
                                text: String(parameterItem.modelData.default || "")
                                placeholderText: parameterItem.modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                                leftPadding: 13
                                rightPadding: pathPickerVisible ? 81 : 45
                                echoMode: parameterItem.modelData.kind === "secret"
                                    ? TextInput.Password : TextInput.Normal
                                background: Rectangle {
                                    radius: Theme.radiusSmall
                                    color: Theme.surfaceContainerLow
                                    border.color: parent.activeFocus ? Theme.primary : Theme.inputBorder
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[parameterItem.modelData.id] = text
                                FilePathDropArea { target: parameterTextField }
                                AppTextEditMenu { target: parameterTextField }

                                ParameterDefaultButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: parameterTextField.pathPickerVisible ? 42 : 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: root.controller.setParameterDefault(
                                        parameterItem.modelData.id, parameterTextField.text)
                                }

                                PrimaryButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parameterTextField.pathPickerVisible
                                    width: 30
                                    height: 30
                                    compact: true
                                    text: parameterItem.modelData.kind === "directory"
                                        ? "选择文件夹" : "选择文件"
                                    iconName: "folder_open"
                                    glyphSize: 19
                                    tonal: true
                                    foregroundColor: Theme.primaryText
                                    border.width: 0
                                    radius: Theme.radiusControl
                                    // Above AppTextEditMenu's input-event overlay (z: 200).
                                    z: 201
                                    color: hovered
                                        ? Theme.primaryContainerHover
                                        : Theme.primaryContainer
                                    onClicked: {
                                        const selectedPath = parameterItem.modelData.kind === "directory"
                                            ? root.controller.chooseParameterDirectory(parameterTextField.text)
                                            : root.controller.chooseParameterFile(parameterTextField.text)
                                        if (selectedPath.length > 0) {
                                            parameterTextField.text = selectedPath
                                            parameterTextField.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: multilineField
                            TextArea {
                                id: parameterTextArea
                                text: String(parameterItem.modelData.default || "")
                                placeholderText: parameterItem.modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                                leftPadding: 13
                                rightPadding: 45
                                wrapMode: TextEdit.Wrap
                                background: Rectangle {
                                    radius: Theme.radiusSmall
                                    color: Theme.surfaceContainerLow
                                    border.color: parent.activeFocus ? Theme.primary : Theme.inputBorder
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[parameterItem.modelData.id] = text
                                FilePathDropArea { target: parameterTextArea }
                                AppTextEditMenu { target: parameterTextArea }
                                ParameterDefaultButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.top: parent.top
                                    anchors.topMargin: 5
                                    onClicked: root.controller.setParameterDefault(
                                        parameterItem.modelData.id, parameterTextArea.text)
                                }
                            }
                        }

                        Component {
                            id: choiceField
                            AppComboBox {
                                id: choiceControl
                                readonly property var choiceOptions: parameterItem.modelData.options || []
                                function optionValue(index) {
                                    if (index < 0 || index >= choiceOptions.length)
                                        return ""
                                    const option = choiceOptions[index]
                                    return typeof option === "object" ? option.value : option
                                }
                                model: choiceOptions
                                textRole: choiceOptions.length > 0 && typeof choiceOptions[0] === "object" ? "label" : ""
                                leftPadding: 13
                                font.pixelSize: Theme.fontBody
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0)
                                        root.parameterValues[parameterItem.modelData.id] = optionValue(currentIndex)
                                }
                            }
                        }

                        Component {
                            id: booleanField
                            AppCheckBox {
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
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }

                    Item { width: 1; height: 8 }
                }
            }

            DeviceSelector {
                width: parent.width
                visible: !!root.displayedTool.uses_android_device
                controller: root.androidBackend
                toolId: root.displayedTool.id || ""
                requiredDevice: !!root.displayedTool.requires_android_device
                explicitTarget: !!root.displayedTool.android_explicit_target
            }
        }
    }

    Item {
        id: actionArea
        objectName: "customActionArea"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: consolePanel.top
        anchors.leftMargin: Theme.detailPanelPadding
        anchors.rightMargin: Theme.detailPanelPadding
        anchors.bottomMargin: Theme.space8
        height: actionFlow.implicitHeight

        Flow {
            id: actionFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.space8
            layoutDirection: root.allowManagement ? Qt.LeftToRight : Qt.RightToLeft

            readonly property real halfButtonWidth: (width - spacing) / 2

            PrimaryButton {
                id: editButton
                objectName: "customEditButton"
                visible: root.allowManagement
                width: root.narrowManagementLayout
                    ? actionFlow.halfButtonWidth : Theme.detailActionWidth
                height: Theme.controlHeightSmall
                radius: Theme.radiusSmall
                text: "编辑脚本"
                iconName: ""
                tonal: true
                color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
                border.color: Theme.outline
                foregroundColor: Theme.textPrimary
                labelFontSize: Theme.fontSupporting
                labelFontWeight: Font.Normal
                glyphSize: 18
                contentSpacing: 7
                enabled: !!root.displayedTool.editable && !root.controller.running
                onClicked: root.editRequested()
            }

            PrimaryButton {
                objectName: "customDeleteButton"
                visible: root.allowManagement
                width: root.narrowManagementLayout
                    ? actionFlow.halfButtonWidth : Theme.detailActionWidth
                height: Theme.controlHeightSmall
                radius: Theme.radiusSmall
                tonal: true
                color: Theme.dangerAction
                border.color: Theme.errorColor
                text: "删除脚本"
                iconName: ""
                foregroundColor: Theme.textPrimary
                labelFontSize: Theme.fontSupporting
                labelFontWeight: Font.Normal
                glyphSize: 18
                contentSpacing: 7
                enabled: !!root.displayedTool.id && !root.controller.running
                onClicked: root.deleteRequested()
            }

            Item {
                visible: root.allowManagement && !root.narrowManagementLayout
                width: Math.max(0, actionFlow.width
                    - Theme.detailActionWidth * 2 - Theme.detailRunWidth
                    - actionFlow.spacing * 3)
                height: Theme.controlHeightSmall
            }

            PrimaryButton {
                id: runButton
                objectName: "customRunButton"
                width: root.allowManagement
                    ? (root.narrowManagementLayout
                        ? actionFlow.width : Theme.detailRunWidth)
                    : Math.min(Theme.detailRunWidth, actionFlow.width)
                height: Theme.controlHeightSmall
                radius: Theme.radiusSmall
                text: root.controller.running ? "停止运行" : "运行脚本"
                iconName: root.controller.running ? "stop" : "play_arrow"
                tonal: true
                color: hovered ? Theme.primaryHover : Theme.primary
                border.width: 0
                foregroundColor: "white"
                labelFontSize: Theme.fontSupporting
                labelFontWeight: Font.Medium
                glyphSize: 16
                contentSpacing: 6
                enabled: !!root.displayedTool.id
                onClicked: root.runSelectedTool()
            }
        }
    }

    Rectangle {
        id: consolePanel
        objectName: "customConsolePanel"
        x: Theme.detailPanelPadding
        width: parent.width - Theme.detailPanelPadding * 2
        readonly property real formReservedHeight: Math.max(Theme.detailFormReservedHeight,
            parameterArea.y + Math.min(parameterColumn.height, Theme.detailFormMaximumVisibleHeight)
            + actionArea.height + Theme.space8 * 2 + Theme.detailPanelPadding)
        height: root.consoleExpanded
            ? Math.min(Theme.consoleMaximumHeight,
                       Math.max(Math.min(Theme.consoleMinimumHeight,
                           Math.max(Theme.consoleHeaderHeight, root.height - parameterArea.y
                               - actionArea.height - Theme.detailPanelPadding * 2)),
                           root.height - formReservedHeight))
            : Theme.consoleHeaderHeight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.detailPanelPadding
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

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.consoleHeaderHeight
            radius: Theme.radiusConsole
            color: Theme.consoleHeaderBackground
            RowLayout {
                objectName: "customConsoleHeader"
                anchors.fill: parent
                anchors.leftMargin: root.compactConsoleActions ? 12 : 15
                anchors.rightMargin: root.compactConsoleActions ? 12 : 15
                spacing: root.compactConsoleActions ? 6 : 10
                Text { text: "控制台输出"; color: Theme.consoleText; font.pixelSize: Theme.fontSupporting; font.weight: Font.DemiBold }
                Item { visible: !root.compactConsoleActions; Layout.preferredWidth: 20 }
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: Theme.radiusTiny
                    color: root.consoleStatusColor
                    Accessible.name: root.controller.statusText
                }
                Text {
                    visible: root.showConsoleStatusText
                    text: root.controller.statusText
                    color: root.consoleStatusColor
                    font.pixelSize: Theme.fontCaption
                }
                Item { Layout.fillWidth: true }
                PrimaryButton {
                    objectName: "customConsoleCopyButton"
                    implicitWidth: root.compactConsoleActions ? 30 : 82
                    implicitHeight: 30
                    radius: Theme.radiusTiny
                    text: "复制输出"
                    iconName: "content_copy"
                    compact: root.compactConsoleActions
                    Accessible.name: "复制控制台输出"
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
                    radius: Theme.radiusTiny
                    text: "清空"
                    iconName: "delete_sweep"
                    compact: root.compactConsoleActions
                    Accessible.name: "清空控制台输出"
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
                    radius: Theme.radiusTiny
                    text: root.consoleExpanded ? "收起" : "展开"
                    iconName: root.consoleExpanded ? "expand_more" : "expand_less"
                    compact: root.compactConsoleActions
                    Accessible.name: root.consoleExpanded ? "收起控制台输出" : "展开控制台输出"
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
            anchors.leftMargin: Theme.space12
            anchors.rightMargin: Theme.space12
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
                font.pixelSize: Theme.fontCaption
                background: null
                AppTextEditMenu { target: consoleText }
                onTextChanged: Qt.callLater(consolePanel.scrollConsoleToBottom)
                onContentHeightChanged: Qt.callLater(consolePanel.scrollConsoleToBottom)
            }
        }

        Rectangle {
            id: footer
            radius: Theme.radiusConsole
            visible: consolePanel.height > 43
            opacity: root.consoleExpanded ? 1 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.consoleFooterHeight
            color: Theme.consoleBackground
            border.color: Theme.darkMode ? "#2A3442" : "#25303D"
            border.width: 1
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: "脚本输出"; color: Theme.consoleMuted; font.pixelSize: Theme.fontSmall }
            Text { anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: root.controller.statusText; color: Theme.consoleMuted; font.pixelSize: Theme.fontSmall }
        }
    }

}
