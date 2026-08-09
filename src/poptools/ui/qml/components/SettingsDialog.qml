import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    objectName: "settingsDialog"

    required property var controller
    required property var parentWindow

    signal restartRequested()

    property string initialPythonProvider: ""
    property string initialPythonExecutable: ""
    readonly property bool pythonEnvironmentModified:
        pythonProviderBox.currentValue !== initialPythonProvider
        || customPythonField.text.trim() !== initialPythonExecutable


    width: Math.min(680, root.parentWindow.width - 24)
    height: Math.min(600, root.parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        themeModeBox.currentIndex = Math.max(0, ["system", "light", "dark"].indexOf(
                                                 root.controller.themeMode))
        startupWidthField.text = String(root.controller.startupWindowWidth)
        startupHeightField.text = String(root.controller.startupWindowHeight)
        startupCenteredSwitch.checked = root.controller.startupWindowCentered
        middlePanelColorField.text = root.controller.middlePanelColor
        pythonProviderBox.currentIndex = root.controller.pythonProvider === "custom" ? 1 : 0
        customPythonField.text = root.controller.customPythonExecutable
        initialPythonProvider = pythonProviderBox.currentValue
        initialPythonExecutable = customPythonField.text.trim()
    }

    Connections {
        target: root.controller
        function onPythonEnvironmentSaveFinished(success) {
            if (!success)
                return
            root.initialPythonProvider = pythonProviderBox.currentValue
            root.initialPythonExecutable = customPythonField.text.trim()
            root.close()
            root.restartRequested()
        }
    }

    QtDialogs.ColorDialog {
        id: middlePanelColorDialog
        title: "选择中栏颜色"
        onAccepted: middlePanelColorField.text = selectedColor.toString().toUpperCase()
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "设置"
                    color: Theme.textPrimary
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 21
                    color: closeMouse.containsMouse
                           ? Theme.surfaceContainerHigh : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        iconSize: 22
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        ScrollView {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: settingsScroll.availableWidth
                spacing: 14

                Item { Layout.preferredHeight: 6 }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: appearanceContent.implicitHeight + 36
                    radius: 16
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: appearanceContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "palette"; iconSize: 22; color: Theme.primary }
                            Text {
                                text: "外观"
                                color: Theme.textPrimary
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            Text {
                                Layout.fillWidth: true
                                text: "主题"
                                color: Theme.textPrimary
                                font.pixelSize: 14
                            }
                            AppComboBox {
                                id: themeModeBox
                                objectName: "themeModeBox"
                                Layout.preferredWidth: 230
                                implicitHeight: 46
                                font.pixelSize: 14
                                textRole: "label"
                                valueRole: "value"
                                model: [
                                    { "label": "跟随系统", "value": "system" },
                                    { "label": "浅色", "value": "light" },
                                    { "label": "深色", "value": "dark" }
                                ]
                                onActivated: root.controller.saveThemeMode(currentValue)
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outlineVariant }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "冷启动窗口尺寸"
                                color: Theme.textPrimary
                                font.pixelSize: 14
                            }
                            Switch {
                                id: startupCenteredSwitch
                                text: "屏幕居中"
                                font.pixelSize: 14
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            TextField {
                                id: startupWidthField
                                Layout.fillWidth: true
                                implicitHeight: 46
                                placeholderText: "宽度 600–7680"
                                color: Theme.textPrimary
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 600; top: 7680 }
                                font.pixelSize: 14
                                leftPadding: 14
                                rightPadding: 14
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                            }
                            Text { text: "×"; color: Theme.textSecondary; font.pixelSize: 16 }
                            TextField {
                                id: startupHeightField
                                Layout.fillWidth: true
                                implicitHeight: 46
                                placeholderText: "高度 448–4320"
                                color: Theme.textPrimary
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 448; top: 4320 }
                                font.pixelSize: 14
                                leftPadding: 14
                                rightPadding: 14
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                            }
                            PrimaryButton {
                                implicitWidth: 92
                                implicitHeight: 46
                                text: "保存"
                                iconName: "save"
                                tonal: true
                                onClicked: root.controller.saveStartupWindowSize(
                                               parseInt(startupWidthField.text),
                                               parseInt(startupHeightField.text),
                                               startupCenteredSwitch.checked)
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outlineVariant }

                        Text {
                            text: "中栏颜色"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: Theme.radiusMedium
                                color: middlePanelColorField.acceptableInput
                                       ? middlePanelColorField.text : root.controller.middlePanelColor
                                border.color: Theme.outline
                            }
                            TextField {
                                id: middlePanelColorField
                                Layout.fillWidth: true
                                implicitHeight: 46
                                placeholderText: "#RRGGBB 或 #AARRGGBB"
                                color: Theme.textPrimary
                                validator: RegularExpressionValidator {
                                    regularExpression: /#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})/
                                }
                                font.family: "Cascadia Mono"
                                font.pixelSize: 14
                                leftPadding: 14
                                rightPadding: 14
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                            }
                            PrimaryButton {
                                implicitWidth: 92
                                implicitHeight: 46
                                text: "取色"
                                iconName: "colorize"
                                tonal: true
                                onClicked: {
                                    if (middlePanelColorField.acceptableInput)
                                        middlePanelColorDialog.selectedColor = middlePanelColorField.text
                                    middlePanelColorDialog.open()
                                }
                            }
                            PrimaryButton {
                                implicitWidth: 92
                                implicitHeight: 46
                                text: "保存"
                                iconName: "palette"
                                tonal: true
                                enabled: middlePanelColorField.acceptableInput
                                onClicked: root.controller.saveMiddlePanelColor(middlePanelColorField.text)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: pythonContent.implicitHeight + 36
                    radius: 16
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: pythonContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "terminal"; iconSize: 22; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "Python 运行环境"
                                color: Theme.textPrimary
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "Doctor 与脚本共用"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }
                        }

                        AppComboBox {
                            id: pythonProviderBox
                            objectName: "pythonProviderBox"
                            Layout.fillWidth: true
                            implicitHeight: 46
                            font.pixelSize: 14
                            textRole: "label"
                            valueRole: "value"
                            model: [
                                { "label": "PopTools 专用环境（推荐）", "value": "managed" },
                                { "label": "自定义本地 Python 3.11+", "value": "custom" }
                            ]
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: pythonProviderBox.currentValue === "custom"
                            spacing: 10
                            TextField {
                                id: customPythonField
                                Layout.fillWidth: true
                                implicitHeight: 46
                                placeholderText: "选择 python.exe"
                                color: Theme.textPrimary
                                font.family: "Cascadia Mono"
                                font.pixelSize: 13
                                leftPadding: 14
                                rightPadding: 14
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                            }
                            PrimaryButton {
                                implicitWidth: 96
                                implicitHeight: 46
                                text: "浏览"
                                iconName: "folder_open"
                                tonal: true
                                onClicked: {
                                    var selected = root.controller.choosePythonExecutable()
                                    if (selected.length > 0)
                                        customPythonField.text = selected
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(48, environmentStatus.implicitHeight + 20)
                            radius: Theme.radiusMedium
                            color: Theme.surface
                            border.color: Theme.outlineVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 10
                                MaterialIcon {
                                    icon: "check_circle"
                                    iconSize: 19
                                    color: Theme.success
                                }
                                Text {
                                    id: environmentStatus
                                    Layout.fillWidth: true
                                    text: root.controller.pythonEnvironmentStatus + " · "
                                          + root.controller.pythonExecutable
                                    wrapMode: Text.WrapAnywhere
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                }
                                PrimaryButton {
                                    visible: root.pythonEnvironmentModified
                                    implicitWidth: 118
                                    implicitHeight: 40
                                    text: root.controller.pythonValidationRunning ? "正在验证" : "应用更改"
                                    iconName: "restart_alt"
                                    enabled: !root.controller.pythonValidationRunning
                                    onClicked: {
                                        root.controller.savePythonEnvironment(
                                                    pythonProviderBox.currentValue,
                                                    customPythonField.text)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: scriptsContent.implicitHeight + 36
                    radius: 16
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: scriptsContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "folder_copy"; iconSize: 22; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "客制功能脚本"
                                color: Theme.textPrimary
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: Theme.radiusMedium
                            color: Theme.surface
                            border.color: Theme.outlineVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 6
                                spacing: 10
                                Text {
                                    Layout.fillWidth: true
                                    text: root.controller.configurationDirectory
                                    color: Theme.textPrimary
                                    font.family: "Cascadia Mono"
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: Theme.radiusMedium
                                    color: configFolderMouse.containsMouse
                                           ? Theme.primaryContainer : "transparent"
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "folder_open"
                                        iconSize: 21
                                        color: Theme.primary
                                    }
                                    MouseArea {
                                        id: configFolderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.controller.openConfigurationDirectory()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "导入会备份并替换默认目录中的脚本；导出至“文档”目录。"
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            PrimaryButton {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                text: "导入脚本"
                                iconName: "upload_file"
                                tonal: true
                                onClicked: root.controller.importConfiguration()
                            }
                            PrimaryButton {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                text: "导出脚本"
                                iconName: "download"
                                onClicked: root.controller.exportConfiguration()
                            }
                        }

                        Text {
                            visible: root.controller.configurationStatus.length > 0
                            Layout.fillWidth: true
                            text: root.controller.configurationStatus
                            wrapMode: Text.WrapAnywhere
                            color: text.indexOf("失败") >= 0 || text.indexOf("无法") >= 0
                                   ? Theme.errorColor : Theme.success
                            font.pixelSize: 12
                        }
                    }
                }

                Item { Layout.preferredHeight: 6 }
            }
        }
    }
}
