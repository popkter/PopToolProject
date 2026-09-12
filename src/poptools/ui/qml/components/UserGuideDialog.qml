import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
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
                text: "用几步了解如何管理自定义脚本、使用 Android 预设、配置 Jira 飞书推送、管理运行环境与应用更新。"
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

        DesktopScrollView {
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
                                text: "1. 管理自定义脚本"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“自定义”，在左侧搜索、筛选并选择脚本，在右侧配置参数和查看控制台输出。点击“新建脚本”可创建 PowerShell、Bash、Batch 或 Python 脚本；选中脚本后可以运行、停止、编辑、分享或删除。"
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
                                text: "2. 用模板生成参数控件"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "${参数名} 生成文本框，${参数名:默认值} 生成带默认值的文本框，${模式:开启=1|关闭=0} 生成下拉菜单，${APK文件@file} 生成带文件选择按钮的路径框。需要重复使用或分开内部名与显示名时，可先写 Var serial = ${设备序列号:emulator-5554}，再在脚本中使用 ${serial}；Var 声明行不会被执行。"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSupporting
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: androidGuide.implicitHeight + 32
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: androidGuide
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { icon: "android"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "3. 使用 Android 预设"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“预设”，可按模拟、环境、硬件、跳转、其他设备操作和其他预设分类查找功能，也可以直接搜索名称或说明。先在左下角选择目标设备，再运行按键模拟、应用管理、文件操作、截图录屏、无线调试、设备信息、Logcat、投屏或联合录制等功能。"
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
                                text: "4. 配置 Jira 飞书推送"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "在“预设”的“其他预设”分类中打开 Jira 飞书推送，新建或选择方案，填写 Jira 地址、Token/PAT、JQL 和飞书机器人信息。保存后可测试连接、预览消息、立即推送或启动定时任务；凭据与方案保存在本机，定时任务仅在应用进程运行期间生效。"
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
                            MaterialIcon { icon: "settings"; iconSize: 24; color: Theme.primary }
                            Text {
                                Layout.fillWidth: true
                                text: "5. 管理设置与 Python 环境"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "进入“设置”可切换跟随系统、浅色或深色模式，打开脚本目录，批量导入或导出脚本，并选择每天、每周或从不检查更新。新建、编辑或运行 Python 脚本时，应用会检查 import；确认后可把缺失依赖安装到应用专属 Python 环境。"
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
                                text: "6. 使用内置终端"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontComponentTitle
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "点击左侧“终端”即可进入；Windows 首次使用时按提示安装应用专用 PowerShell 7，macOS 使用系统 Shell。终端支持多个独立会话，并与自定义 Python 脚本共用应用专属 python、pip 和 ADB。Ctrl+C 有选区时复制、无选区时停止当前命令，Ctrl+V 粘贴，Ctrl+L 清屏。"
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
