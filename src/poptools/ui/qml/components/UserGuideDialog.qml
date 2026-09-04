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
                text: "用几步了解如何创建客制、配置 Jira 飞书推送、切换主题、管理 Python 依赖，以及使用内置终端。"
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
            id: guideScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 26
            Layout.rightMargin: 26
            Layout.topMargin: 18
            Layout.bottomMargin: 14
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: ScrollBar {
                id: guideScrollBar
                policy: ScrollBar.AsNeeded
                implicitWidth: 8
                background: Rectangle { color: "transparent" }
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: width / 2
                    color: guideScrollBar.pressed ? Theme.primary : Theme.outline
                    opacity: guideScrollBar.active ? 1 : 0.55
                }
            }

            ColumnLayout {
                width: guideScroll.availableWidth
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
                                text: "2. 用变量生成参数控件"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "在脚本中写 ${参数名} 会自动生成输入框；写 ${参数名:默认值} 会生成带默认值的输入框。输入内容与默认值不同时，可点击输入框右侧的“设为默认值”将内容写回客制脚本。${触摸点显示:开启=1|关闭=0} 会生成标题为“触摸点显示”的下拉菜单，并在执行时使用所选项的值。需要重复使用时，可在开头写 pVal serial = ${设备序列号:emulator-5554}，之后使用 ${serial}。pVal 声明行不会被执行。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: jiraGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: jiraGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "send"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "3. 配置 Jira 飞书推送"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“预设 → Jira 飞书推送”，新建或选择方案，填写 Jira 地址、Token/PAT 和 JQL；再配置飞书机器人 Webhook 及安全校验。建议依次使用“测试连接”“预览消息”“保存配置”和“立即推送”。定时推送只在应用保持运行时生效；Token、Webhook 与应用凭据仅保存在本机。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: themeGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: themeGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "palette"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "4. 选择主题外观"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“设置 → 外观”，可选择跟随系统、浅色或深色模式。主题风格会从内置目录和用户数据目录下的 themes 目录动态加载；每次打开设置都会刷新列表，用户主题可覆盖同名内置主题。修改会立即生效并在下次启动时保留，不会影响脚本和推送方案。"
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
                                text: "5. 自动配置 Python 依赖"
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
                                text: "6. 开启并使用内置终端"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "终端功能默认关闭。Windows 首次开启时需确认安装应用专用 PowerShell 7，macOS 使用系统 Shell；运行环境就绪后主界面显示“终端”。终端最多支持 7 个独立会话，并与客制 Python 脚本共用应用专属 python 和 pip。Ctrl+C 有选区时复制、无选区时停止当前命令，Ctrl+V 粘贴，Ctrl+L 清屏。再次关闭终端功能会隐藏入口并停止全部会话。"
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
