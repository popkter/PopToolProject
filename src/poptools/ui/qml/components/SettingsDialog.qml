import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    objectName: "settingsDialog"

    required property var controller
    required property var parentWindow
    signal terminalEnableRequested()

    width: Math.min(680, root.parentWindow.width - 24)
    height: Math.min(600, root.parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        themeModeBox.currentIndex = Math.max(0, ["system", "light", "dark"].indexOf(
                                                 root.controller.themeMode))
        themeStyleBox.currentIndex = Math.max(0, ["material3", "winxp", "mario"].indexOf(
                                                 root.controller.themeStyle))
        concurrencyBox.currentIndex = Math.max(0, root.controller.customScriptConcurrency - 1)
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
                    font.pixelSize: Theme.fontDialogTitle
                    font.weight: Font.Bold
                }
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: height / 2
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
            Layout.bottomMargin: Theme.radiusLarge
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
                    radius: Theme.radiusMedium
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
                                font.pixelSize: Theme.fontComponentTitle
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
                                font.pixelSize: Theme.fontBody
                            }
                            AppComboBox {
                                id: themeModeBox
                                objectName: "themeModeBox"
                                Layout.preferredWidth: 230
                                implicitHeight: 46
                                font.pixelSize: Theme.fontBody
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            Text {
                                Layout.fillWidth: true
                                text: "主题风格"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                            }
                            AppComboBox {
                                id: themeStyleBox
                                objectName: "themeStyleBox"
                                Layout.preferredWidth: 230
                                implicitHeight: 46
                                font.pixelSize: Theme.fontBody
                                textRole: "label"
                                valueRole: "value"
                                model: [
                                    { "label": "Material 3", "value": "material3" },
                                    { "label": "Windows XP", "value": "winxp" },
                                    { "label": "Mario", "value": "mario" }
                                ]
                                onActivated: root.controller.saveThemeStyle(currentValue)
                            }
                        }

                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: pythonContent.implicitHeight + 36
                    radius: Theme.radiusMedium
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
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "应用专属"
                                color: Theme.success
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(54, environmentStatus.implicitHeight + 20)
                            radius: Theme.radiusMedium
                            color: Theme.surface
                            border.color: Theme.outlineVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                MaterialIcon {
                                    icon: "check_circle"
                                    iconSize: 19
                                    color: Theme.success
                                }
                                Text {
                                    id: environmentStatus
                                    Layout.fillWidth: true
                                    text: root.controller.pythonEnvironmentStatus + "\n" + root.controller.pythonExecutable
                                    wrapMode: Text.WrapAnywhere
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Python 脚本的第三方依赖可直接在依赖提示中使用应用内 pip 安装。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontCaption
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: terminalContent.implicitHeight + 36
                    radius: Theme.radiusMedium
                    color: terminalSettingsMouse.containsMouse
                           ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    RowLayout {
                        id: terminalContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 12

                        MaterialIcon {
                            icon: "terminal"
                            iconSize: 22
                            color: Theme.primary
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "终端功能"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.controller.terminalEnabled
                                    ? "已开启，主界面显示终端 Tab"
                                    : "开启后可使用应用专属 "
                                      + developerConsoleController.terminalName + " 终端"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.WordWrap
                            }
                        }
                        Switch {
                            checked: root.controller.terminalEnabled
                            enabled: false
                            opacity: 1
                        }
                    }

                    MouseArea {
                        id: terminalSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.controller.terminalEnabled)
                                root.controller.saveTerminalEnabled(false)
                            else
                                root.terminalEnableRequested()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: scriptsContent.implicitHeight + 36
                    radius: Theme.radiusMedium
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
                                text: "客制"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "脚本并发数量"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontBody
                                }
                                Text {
                                    text: "限制同时运行的客制脚本数量"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                            AppComboBox {
                                id: concurrencyBox
                                objectName: "customScriptConcurrencyBox"
                                Layout.preferredWidth: 150
                                implicitHeight: 46
                                textRole: "label"
                                valueRole: "value"
                                model: [
                                    { "label": "1 个", "value": 1 },
                                    { "label": "2 个", "value": 2 },
                                    { "label": "3 个", "value": 3 },
                                    { "label": "4 个", "value": 4 },
                                    { "label": "5 个", "value": 5 }
                                ]
                                onActivated: root.controller.saveCustomScriptConcurrency(currentValue)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.outlineVariant
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
                                    font.pixelSize: Theme.fontCaption
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
                            text: "导入会先备份，再与现有脚本合并；同名脚本使用导入版本。导出至“文档”目录。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontCaption
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
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }

                Item { Layout.preferredHeight: 6 }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "泡泡工具箱 版本 " + root.controller.appVersion
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontCaption
                    font.underline: true
                    bottomPadding: 16

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(root.controller.appInfoUrl)
                    }
                }
            }
        }
    }
}
