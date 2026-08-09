import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    property bool editMode: false
    property string selectedIcon: "terminal"
    readonly property var commandIcons: [
        { "label": "终端", "value": "terminal" },
        { "label": "代码", "value": "code" },
        { "label": "构建", "value": "build" },
        { "label": "设置", "value": "settings" },
        { "label": "主页", "value": "home" },
        { "label": "应用", "value": "apps" },
        { "label": "仪表盘", "value": "dashboard" },
        { "label": "工具", "value": "handyman" },
        { "label": "调节", "value": "tune" },
        { "label": "扩展", "value": "extension" },
        { "label": "收藏", "value": "star" },
        { "label": "书签", "value": "bookmark" },
        { "label": "标签", "value": "label" },
        { "label": "信息", "value": "info" },
        { "label": "帮助", "value": "help" },
        { "label": "通知", "value": "notifications" },

        { "label": "脚本", "value": "integration_instructions" },
        { "label": "命令", "value": "input" },
        { "label": "控制台", "value": "developer_mode" },
        { "label": "网页", "value": "web" },
        { "label": "接口", "value": "http" },
        { "label": "存储", "value": "storage" },
        { "label": "数据", "value": "dns" },
        { "label": "内存", "value": "memory" },
        { "label": "处理器", "value": "developer_board" },
        { "label": "组件", "value": "widgets" },
        { "label": "提交", "value": "commit" },
        { "label": "合并", "value": "merge_type" },
        { "label": "分支", "value": "account_tree" },

        { "label": "Android", "value": "android" },
        { "label": "手机", "value": "smartphone" },
        { "label": "安卓手机", "value": "phone_android" },
        { "label": "平板", "value": "tablet_android" },
        { "label": "设备", "value": "devices" },
        { "label": "显示器", "value": "monitor" },
        { "label": "电脑", "value": "computer" },
        { "label": "键盘", "value": "keyboard" },
        { "label": "鼠标", "value": "mouse" },
        { "label": "USB", "value": "usb" },
        { "label": "蓝牙", "value": "bluetooth" },
        { "label": "投屏", "value": "cast" },
        { "label": "连接投屏", "value": "cast_connected" },
        { "label": "设备中心", "value": "devices_other" },

        { "label": "文件夹", "value": "folder" },
        { "label": "打开文件夹", "value": "folder_open" },
        { "label": "新建文件夹", "value": "create_new_folder" },
        { "label": "文件", "value": "insert_drive_file" },
        { "label": "文档", "value": "description" },
        { "label": "复制", "value": "content_copy" },
        { "label": "剪切", "value": "content_cut" },
        { "label": "粘贴", "value": "content_paste" },
        { "label": "保存", "value": "save" },
        { "label": "归档", "value": "archive" },
        { "label": "解压", "value": "unarchive" },
        { "label": "删除", "value": "delete" },
        { "label": "恢复", "value": "restore" },
        { "label": "打印", "value": "print" },

        { "label": "搜索", "value": "search" },
        { "label": "筛选", "value": "filter_alt" },
        { "label": "排序", "value": "sort" },
        { "label": "列表", "value": "list" },
        { "label": "检查列表", "value": "checklist" },
        { "label": "添加", "value": "add_circle" },
        { "label": "编辑", "value": "edit" },
        { "label": "刷新", "value": "refresh" },
        { "label": "同步", "value": "sync" },
        { "label": "启动", "value": "play_arrow" },
        { "label": "停止", "value": "stop" },
        { "label": "暂停", "value": "pause" },
        { "label": "跳过", "value": "skip_next" },
        { "label": "计划", "value": "schedule" },
        { "label": "计时器", "value": "timer" },
        { "label": "闪电", "value": "bolt" },
        { "label": "电源", "value": "power_settings_new" },
        { "label": "清理", "value": "cleaning_services" },
        { "label": "完成", "value": "task_alt" },
        { "label": "撤销", "value": "undo" },
        { "label": "重做", "value": "redo" },

        { "label": "云端", "value": "cloud" },
        { "label": "云上传", "value": "cloud_upload" },
        { "label": "云下载", "value": "cloud_download" },
        { "label": "下载", "value": "download" },
        { "label": "上传", "value": "upload" },
        { "label": "链接", "value": "link" },
        { "label": "公网", "value": "public" },
        { "label": "语言", "value": "language" },
        { "label": "Wi-Fi", "value": "wifi" },
        { "label": "路由器", "value": "router" },
        { "label": "热点", "value": "wifi_tethering" },
        { "label": "信号", "value": "network_check" },
        { "label": "RSS", "value": "rss_feed" },
        { "label": "发送", "value": "send" },

        { "label": "调试", "value": "bug_report" },
        { "label": "性能", "value": "speed" },
        { "label": "监控", "value": "monitor_heart" },
        { "label": "安全", "value": "security" },
        { "label": "密钥", "value": "vpn_key" },
        { "label": "钥匙", "value": "key" },
        { "label": "锁定", "value": "lock" },
        { "label": "解锁", "value": "lock_open" },
        { "label": "可见", "value": "visibility" },
        { "label": "隐藏", "value": "visibility_off" },
        { "label": "盾牌", "value": "verified_user" },
        { "label": "警告", "value": "warning" },
        { "label": "错误", "value": "error" },

        { "label": "麦克风", "value": "mic" },
        { "label": "音量", "value": "volume_up" },
        { "label": "耳机", "value": "headphones" },
        { "label": "语音", "value": "record_voice_over" },
        { "label": "图片", "value": "image" },
        { "label": "相机", "value": "photo_camera" },
        { "label": "调色板", "value": "palette" },
        { "label": "计算器", "value": "calculate" },
        { "label": "函数", "value": "functions" },
        { "label": "百分比", "value": "percent" }
    ]
    readonly property var commandKinds: [
        { "label": "PowerShell", "value": "powershell" },
        { "label": "Bash", "value": "bash" },
        { "label": "BAT 脚本", "value": "batch" },
        { "label": "Python", "value": "python" }
    ]
    width: Math.min(760, Overlay.overlay.width - 24)
    height: Math.min(720, Overlay.overlay.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    function kindIndex(value) {
        var choices = commandKinds
        for (var index = 0; index < choices.length; index++) {
            if (choices[index].value === value)
                return index
        }
        return 0
    }

    function openForCreate() {
        editMode = false
        titleField.text = ""
        descriptionField.text = ""
        kindBox.currentIndex = 0
        commandArea.text = ""
        selectedIcon = "terminal"
        open()
        titleField.forceActiveFocus()
    }

    function openForEdit() {
        var tool = controller.selectedTool
        editMode = true
        titleField.text = tool.title || ""
        descriptionField.text = tool.description || ""
        selectedIcon = tool.presentation && tool.presentation.icon
                       ? tool.presentation.icon : "terminal"
        kindBox.currentIndex = kindIndex(tool.executor ? tool.executor.kind : "powershell")
        var executor = tool.executor || {}
        var scriptParts = []
        if (executor.command)
            scriptParts.push(executor.command)
        if (executor.args) {
            for (var index = 0; index < executor.args.length; index++)
                scriptParts.push(executor.args[index])
        }
        commandArea.text = scriptParts.join(" ")
        open()
        commandArea.forceActiveFocus()
    }

    function submit() {
        var saved = editMode
                ? controller.saveSelected(titleField.text, descriptionField.text,
                                          kindBox.currentValue, commandArea.text,
                                          selectedIcon)
                : controller.createCommand(titleField.text, descriptionField.text,
                                           kindBox.currentValue, commandArea.text,
                                           selectedIcon)
        if (saved)
            close()
    }

    background: Rectangle {
        radius: 22
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            color: Theme.surfaceContainerLow
            radius: 22
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                color: parent.color
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 15
                    color: Theme.primaryContainer
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: root.editMode ? "edit_note" : "add_circle"
                        iconSize: 28
                        color: Theme.primary
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: root.editMode ? "编辑脚本" : "新建脚本"
                        color: Theme.textPrimary
                        font.pixelSize: 23
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "命令和脚本内容将保存在本地配置中"

                        color: Theme.textSecondary
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 21
                    color: closeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    MaterialIcon { anchors.centerIn: parent; icon: "close"; iconSize: 23; color: Theme.textSecondary }
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

        ScrollView {
            id: formScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded


        }

              ColumnLayout {
                width: formScroll.availableWidth
                spacing: 15

                Item { Layout.preferredHeight: 4 }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    columns: width < 560 ? 1 : 2
                    columnSpacing: 14
                    rowSpacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 440
                        spacing: 6
                        Text { text: "命令名称"; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                        TextField {
                            id: titleField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            leftPadding: 64
                            rightPadding: 15
                            placeholderText: "例如：打开系统设置"
                            color: Theme.textPrimary
                            background: Rectangle {
                                radius: Theme.radiusMedium
                                color: Theme.surface
                                border.color: titleField.activeFocus || iconPopup.opened
                                              ? Theme.primary : Theme.outline
                                border.width: titleField.activeFocus || iconPopup.opened ? 2 : 1
                            }

                            Rectangle {
                                id: iconButton
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                height: 40
                                radius: 10
                                z: 2
                                color: iconButtonMouse.containsMouse || iconPopup.opened
                                       ? Theme.primaryContainer : Theme.surfaceContainerLow

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: root.selectedIcon
                                    iconSize: 24
                                    color: Theme.primary
                                }
                                ToolTip.visible: iconButtonMouse.containsMouse
                                ToolTip.text: "点击选择命令图标"
                                MouseArea {
                                    id: iconButtonMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: iconPopup.open()
                                }

                                Popup {
                                    id: iconPopup
                                    x: -5
                                    y: iconButton.height + 8
                                    width: Math.min(300, root.width - 44)
                                    height: 214
                                    padding: 8
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                    background: Rectangle {
                                        radius: Theme.radiusMedium
                                        color: Theme.surface
                                        border.color: Theme.outlineVariant
                                        border.width: 1
                                    }

                                    contentItem: GridView {
                                        cellWidth: 52
                                        cellHeight: 48
                                        model: root.commandIcons
                                        clip: true
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                        delegate: Rectangle {
                                            id: iconChoice
                                            required property var modelData
                                            width: 44
                                            height: 40
                                            radius: 10
                                            color: root.selectedIcon === modelData.value
                                                   ? Theme.primaryContainer
                                                   : (iconMouse.containsMouse
                                                      ? Theme.surfaceContainerHigh : "transparent")
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                icon: iconChoice.modelData.value
                                                iconSize: 25
                                                color: root.selectedIcon === iconChoice.modelData.value
                                                       ? Theme.primary : Theme.textSecondary
                                            }
                                            ToolTip.visible: iconMouse.containsMouse
                                            ToolTip.text: modelData.label
                                            MouseArea {
                                                id: iconMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.selectedIcon = iconChoice.modelData.value
                                                    iconPopup.close()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 220
                        spacing: 6
                        Text { text: "运行方式"; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                        AppComboBox {
                            id: kindBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            model: root.commandKinds
                            textRole: "label"
                            valueRole: "value"
                            leftPadding: 14
                        }
                    }
                }


                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    spacing: 6
                    Text { text: "功能说明"; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                    TextField {
                        id: descriptionField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        leftPadding: 15
                        rightPadding: 15
                        topPadding: 12
                        bottomPadding: 12
                        placeholderText: "简要说明命令用途"
                        wrapMode: TextEdit.Wrap
                        color: Theme.textPrimary
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: Theme.surface
                            border.color: descriptionField.activeFocus ? Theme.primary : Theme.outline
                            border.width: descriptionField.activeFocus ? 2 : 1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 292
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    radius: Theme.radiusLarge
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            Layout.leftMargin: 18
                            Layout.rightMargin: 16
                            spacing: 8

                            Text {
                                text: "脚本内容"
                                color: Theme.primary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "支持 pVal 声明和 ${参数名=默认值} 快速写法"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.outlineVariant
                        }

                        ScrollView {
                            id: commandScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 10
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            TextArea {
                                id: commandArea
                                width: Math.max(commandScroll.availableWidth,
                                                contentWidth + leftPadding + rightPadding)
                                height: Math.max(commandScroll.availableHeight,
                                                 contentHeight + topPadding + bottomPadding)
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 10
                                bottomPadding: 10
                                placeholderText: "例如：pVal vin = ${请输入vin=VIN123}\nadb shell setprop persist.sys.vin ${vin}"
                                color: Theme.textPrimary
                                selectionColor: Theme.primary
                                selectedTextColor: "white"
                                font.family: "Cascadia Mono"
                                font.pixelSize: 13
                                wrapMode: TextEdit.NoWrap
                                selectByMouse: true
                                background: null
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    Layout.preferredHeight: helperText.implicitHeight + 22
                    radius: Theme.radiusMedium
                    color: Theme.tealContainer
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        spacing: 9
                        MaterialIcon { icon: "info"; iconSize: 20; color: Theme.teal }
                        Text {
                            id: helperText
                            Layout.fillWidth: true
                            text: "pVal vin = ${显示名称=默认值} 可先声明并多次使用 ${vin}；也兼容冒号声明及原有 ${参数名} 快速写法。"
                            color: Theme.teal
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Item { Layout.preferredHeight: 5 }
            }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 22
            color: Theme.surface
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outlineVariant
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 10

                Item { Layout.fillWidth: true }
                PrimaryButton {
                    implicitWidth: 104
                    implicitHeight: 48
                    text: "取消"
                    iconName: ""
                    tonal: true
                    onClicked: root.close()
                }
                PrimaryButton {
                    implicitWidth: 120
                    implicitHeight: 48
                    text: root.editMode ? "保存" : "创建"
                    iconName: root.editMode ? "save" : "add"
                    onClicked: root.submit()
                }
            }
        }
    }
}
