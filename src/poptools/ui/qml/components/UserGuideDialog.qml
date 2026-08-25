import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    objectName: "userGuideDialog"

    required property var controller
    required property var parentWindow

    width: Math.min(680, parentWindow.width - 24)
    height: Math.min(620, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.NoAutoClose
    padding: 0

    function finishGuide() {
        controller.markUserGuideSeen()
        close()
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 26
            Layout.rightMargin: 26
            Layout.topMargin: 24
            Layout.bottomMargin: 16
            spacing: 7

            Text {
                Layout.fillWidth: true
                text: "欢迎使用泡泡工具箱"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontTitleLarge
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: "用几步了解如何创建客制、生成参数输入框、管理 Python 依赖，以及使用内置终端。"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 26
            Layout.rightMargin: 26
            Layout.topMargin: 18
            Layout.bottomMargin: 14
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: root.width - 52
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: customGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: customGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "build"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "1. 创建客制"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“客制”，点击新建脚本，选择 PowerShell、Bash、BAT 或 Python，填写脚本内容后保存。客制保存在本机，可以编辑、删除和重复运行。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: variableGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: variableGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "input"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "2. 用变量生成输入框"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "在脚本中写 ${参数名} 会自动生成输入框；写 ${参数名=默认值} 会生成带默认值的输入框。需要重复使用时，可在开头写 pVal serial = ${设备序列号=emulator-5554}，之后使用 ${serial}。pVal 声明行不会被执行。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: pythonGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: pythonGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "terminal"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "3. 自动配置 Python 依赖"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "新建、编辑或运行 Python 脚本时，应用会检查 import 的模块。发现常见缺失依赖后，确认即可自动安装到应用专属 Python 环境；也可以点击运行按钮左侧的依赖检查图标手动检查。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: terminalGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: terminalGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "terminal"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "4. 开启并使用内置终端"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "终端功能默认关闭。请先在“设置”中开启；如果尚未安装应用专用的 PowerShell 7 插件，确认并安装成功后，主界面才会显示“终端”Tab。拒绝安装会保持关闭，再次关闭终端功能会隐藏 Tab 并停止会话。终端中可执行 python --version、pip list、pip install 包名等命令，这里的 python 和 pip 与客制 Python 脚本使用同一个应用专属环境。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 26
            Layout.rightMargin: 26
            Layout.topMargin: 14
            Layout.bottomMargin: 16
            spacing: 10

            Item { Layout.fillWidth: true }

            PrimaryButton {
                text: "稍后查看"
                iconName: "schedule"
                tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                text: "开始使用"
                iconName: "arrow_forward"
                onClicked: root.finishGuide()
            }
        }
    }
}
