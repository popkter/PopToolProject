pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    required property var controller
    required property var updateBackend
    signal terminalEnableRequested()
    signal userHelpRequested()
    color: Theme.darkMode ? Theme.surface : "#FBFCFE"

    function scrollToBottom() {
        settingsFlick.contentY = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
    }

    component Card: Rectangle {
        color: Theme.surfaceContainerLow
        border.color: Theme.outlineVariant
        border.width: 1
        radius: 12
    }

    component SectionTitle: RowLayout {
        id: sectionHeader
        property string iconName: "settings"
        property string title: ""
        property string description: ""
        spacing: Theme.space12
        MaterialIcon {
            icon: parent.iconName
            iconSize: 24
            color: Theme.primary
            Layout.preferredWidth: 28
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: sectionHeader.title; color: Theme.textPrimary; font.pixelSize: Theme.fontSectionTitle; font.weight: Font.Bold }
            Text { text: sectionHeader.description; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space28
        anchors.rightMargin: Theme.space28
        anchors.topMargin: 0
        anchors.bottomMargin: Theme.space28
        spacing: Theme.space16

        WorkspacePageHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            Layout.minimumHeight: 68
            Layout.maximumHeight: 68
            title: "设置"
            titlePixelSize: 28
            description: "应用与开发环境配置"
        }

        Flickable {
            id: settingsFlick
            objectName: "settingsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsGrid.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            acceptedButtons: Qt.NoButton

            GridLayout {
                id: settingsGrid
                width: parent.width
                columns: width >= 1000 ? 2 : 1
                columnSpacing: Theme.space16
                rowSpacing: Theme.space16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 14

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: appearanceContent.implicitHeight + 32
                        ColumnLayout {
                            id: appearanceContent
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            SectionTitle { Layout.fillWidth: true; iconName: "palette"; title: "外观"; description: "选择应用的外观主题" }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.rightMargin: 35
                                spacing: Theme.space12
                                Repeater {
                                    model: [
                                        { label: "浅色", value: "light", icon: "light_mode" },
                                        { label: "深色", value: "dark", icon: "dark_mode" },
                                        { label: "跟随系统", value: "system", icon: "computer" }
                                    ]
                                    delegate: Rectangle {
                                        id: themeChoice
                                        required property var modelData
                                        objectName: "themeChoice_" + modelData.value
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        Layout.minimumHeight: 48
                                        Layout.maximumHeight: 48
                                        radius: Theme.radiusMedium
                                        color: root.controller.themeMode === modelData.value ? Theme.primaryContainer : Theme.surfaceContainerLow
                                        border.width: root.controller.themeMode === modelData.value ? 2 : 1
                                        border.color: root.controller.themeMode === modelData.value ? Theme.primary : Theme.outline
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; icon: themeChoice.modelData.icon; iconSize: 20; color: root.controller.themeMode === themeChoice.modelData.value ? Theme.primary : Theme.textSecondary }
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: themeChoice.modelData.label; color: root.controller.themeMode === themeChoice.modelData.value ? Theme.primary : Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.saveThemeMode(themeChoice.modelData.value) }
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 208
                        ColumnLayout {
                            id: directoryContent
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            SectionTitle { Layout.fillWidth: true; iconName: "folder"; title: "脚本目录"; description: "设置脚本文件的默认存储目录" }
                            PrimaryButton {
                                Layout.fillWidth: true; Layout.preferredHeight: 42
                                radius: Theme.radiusSmall; tonal: true; color: Theme.surfaceContainerLow
                                border.color: Theme.outline
                                text: root.controller.configurationDirectory
                                iconName: "folder_open"
                                foregroundColor: Theme.textSecondary
                                labelFontSize: Theme.fontSupporting
                                labelFontWeight: Font.Normal
                                glyphSize: 18
                                contentSpacing: Theme.space8
                                contentFillWidth: true
                                contentHorizontalPadding: 14
                                labelElide: Text.ElideMiddle
                                onClicked: root.controller.openConfigurationDirectory()
                            }
                            Text { text: "自定义脚本、预设和相关数据将保存在此目录下。"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                            RowLayout {
                                Layout.fillWidth: true; spacing: Theme.space12
                                PrimaryButton { Layout.fillWidth: true; implicitWidth: 0; implicitHeight: 48; tonal: true; color: Theme.surfaceContainerLow; border.color: Theme.darkMode ? Theme.outline : "#333333"; text: "导入脚本"; iconName: "file_upload"; onClicked: root.controller.importConfiguration() }
                                PrimaryButton { Layout.fillWidth: true; implicitWidth: 0; implicitHeight: 48; text: "导出脚本"; iconName: "file_download"; onClicked: root.controller.exportConfiguration() }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 264
                        ColumnLayout {
                            id: updateContent
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            SectionTitle { Layout.fillWidth: true; iconName: "autorenew"; title: "自动更新"; description: "检查新版本并保持应用为最新" }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: (settingsFlick.width - 16) / settingsGrid.columns - 96; spacing: 2
                                    Text { text: "自动检查更新"; color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                                    Text { text: "定期检查新版本，在有新版本时通知我"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                }
                                ToggleControl {
                                    checked: root.updateBackend.updateCheckFrequency !== "never"
                                    onToggled: function(value) { root.updateBackend.setUpdateCheckFrequency(value ? "weekly" : "never") }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.preferredWidth: (settingsFlick.width - 16) / settingsGrid.columns - 96; spacing: 2
                                    Text { text: "接受 Beta 版本更新"; color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                                    Text { text: "接收测试版本，提前体验新功能"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                }
                                ToggleControl {
                                    enabled: root.updateBackend.canChangeUpdateChannel
                                    opacity: enabled ? 1 : 0.5
                                    checked: root.updateBackend.prereleaseUpdatesEnabled
                                    onToggled: function(value) { root.updateBackend.setPrereleaseUpdatesEnabled(value) }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outlineVariant }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "检查更新频率"; color: Theme.textPrimary; font.pixelSize: Theme.fontBody }
                                AppComboBox {
                                    objectName: "updateFrequencyChoice"
                                    Layout.preferredWidth: 130
                                    Layout.preferredHeight: 36
                                    leftPadding: 12
                                    rightPadding: 28
                                    model: ["每天", "每周", "从不"]
                                    currentIndex: ["daily", "weekly", "never"].indexOf(root.updateBackend.updateCheckFrequency)
                                    onActivated: function(index) { root.updateBackend.setUpdateCheckFrequency(["daily", "weekly", "never"][index]) }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 14

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 150
                        ColumnLayout {
                            id: terminalContent
                            anchors.fill: parent; anchors.margins: 16; spacing: 10
                            SectionTitle { Layout.fillWidth: true; iconName: "terminal"; title: "默认终端"; description: "选择打开终端时使用的应用" }
                            AppComboBox {
                                Layout.fillWidth: true; implicitHeight: 42
                                model: ["系统默认终端"]
                            }
                            Text { text: "用于在脚本中打开终端或执行命令。"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 208
                        ColumnLayout {
                            id: androidContent
                            anchors.fill: parent; anchors.margins: 16; spacing: 16
                            SectionTitle { Layout.fillWidth: true; iconName: "android"; title: "Android 设备"; description: "设备连接与调试相关设置" }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: (settingsFlick.width - 16) / settingsGrid.columns - 96; spacing: 2
                                    Text { text: "启动时检查设备"; color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                                    Text { text: "应用启动时自动检测已连接的 Android 设备"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                }
                                ToggleControl { checked: true; onToggled: function(value) { checked = value } }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: (settingsFlick.width - 16) / settingsGrid.columns - 96; spacing: 2
                                    Text { text: "设备变化时显示通知"; color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                                    Text { text: "当设备连接或断开时，在桌面显示通知"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                }
                                ToggleControl { checked: true; onToggled: function(value) { checked = value } }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 150
                        ColumnLayout {
                            id: pythonContent
                            anchors.fill: parent; anchors.margins: 16; spacing: 10
                            SectionTitle { Layout.fillWidth: true; iconName: "code"; title: "Python 环境"; description: "选择用于运行 Python 脚本的环境" }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 42
                                radius: Theme.radiusSmall; color: Theme.surfaceContainerLow; border.color: Theme.outline
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                    MaterialIcon { icon: "code"; iconSize: 18; color: Theme.success }
                                    Text { Layout.fillWidth: true; text: root.controller.pythonExecutable || "系统 Python"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting; elide: Text.ElideMiddle }
                                }
                            }
                            Text { text: "用于运行需要 Python 环境的脚本。"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: aboutContent.implicitHeight + 32
                        ColumnLayout {
                            id: aboutContent
                            anchors.fill: parent; anchors.margins: 16; spacing: 8
                            SectionTitle { Layout.fillWidth: true; iconName: "info"; title: "关于"; description: "应用信息与相关链接" }
                            RowLayout {
                                Layout.fillWidth: true; spacing: Theme.space12
                                Image { Layout.preferredWidth: 48; Layout.preferredHeight: 48; source: Qt.resolvedUrl("../../../resources/icons/app-icon-ui.png"); fillMode: Image.PreserveAspectFit; smooth: true }
                                ColumnLayout { Layout.fillWidth: true; spacing: 2
                                    Text { text: "泡泡工具箱"; color: Theme.textPrimary; font.pixelSize: Theme.fontComponentTitle; font.weight: Font.Bold }
                                    Text { text: "Android 开发者工具  ·  v" + root.controller.appVersion; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outlineVariant }
                            RowLayout {
                                id: aboutActions
                                Layout.fillWidth: true
                                spacing: Theme.space8
                                PrimaryButton {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 40
                                    tonal: true
                                    text: "访问官网"
                                    iconName: "public"
                                    onClicked: Qt.openUrlExternally(root.controller.appInfoUrl)
                                }
                                PrimaryButton {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 40
                                    tonal: true
                                    text: "查看 GitHub"
                                    iconName: "code"
                                    onClicked: Qt.openUrlExternally(root.controller.appInfoUrl)
                                }
                                PrimaryButton {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 40
                                    tonal: true
                                    text: "反馈问题"
                                    iconName: "bug_report"
                                    onClicked: Qt.openUrlExternally(root.controller.appInfoUrl + "/issues")
                                }
                                PrimaryButton {
                                    objectName: "checkUpdateButton"
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 40
                                    tonal: true
                                    text: root.updateBackend.state === "checking" ? "正在检查…" : "检查更新"
                                    iconName: "sync"
                                    iconSpinning: root.updateBackend.state === "checking"
                                    enabled: root.updateBackend.canChangeUpdateChannel
                                    onClicked: root.updateBackend.checkForUpdates()
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space8
                                PrimaryButton {
                                    objectName: "openUserHelpButton"
                                    Layout.preferredWidth: (aboutActions.width - 3 * Theme.space8) / 4
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 40
                                    tonal: true
                                    text: "用户帮助"
                                    iconName: "menu_book"
                                    onClicked: root.userHelpRequested()
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: root.updateBackend.status
                                color: root.updateBackend.state === "error" ? Theme.errorColor : Theme.textSecondary
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
