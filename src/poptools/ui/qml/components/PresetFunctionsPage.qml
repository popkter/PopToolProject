pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    required property var controller
    required property var parentWindow
    required property var parameterValues
    required property var presetUtilities
    required property var androidBackend
    required property var jiraFeishuBackend
    property real toolListWidth: 288
    property string searchQuery: ""
    property bool compact: false
    property bool compactHeight: false
    property bool compactToolList: false
    property bool overlaysVisible: false
    property int selectedCategory: 0
    property int selectedTool: 0
    property bool favorite: false
    property bool includeBasic: true
    property bool includeHardware: true
    property bool includeSystem: false
    property bool includeBuild: false
    readonly property bool popupVisible: false

    signal searchEdited(string query)
    signal confirmRunRequested(var values)

    component PresetCheckRow: Item {
        id: checkRow
        property string text: ""
        property bool checked: false
        signal toggled(bool checked)
        width: 420
        height: 25
        Rectangle {
            x: 0; anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            color: checkRow.checked ? Theme.secondary : "transparent"
            border.color: checkRow.checked ? Theme.secondary : Theme.outline
            MaterialIcon { anchors.centerIn: parent; visible: checkRow.checked; icon: "check"; iconSize: 12; color: "white" }
        }
        Text { x: 22; anchors.verticalCenter: parent.verticalCenter; text: checkRow.text; color: Theme.textPrimary; font.pixelSize: 13 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { checkRow.checked = !checkRow.checked; checkRow.toggled(checkRow.checked) } }
    }

    color: Theme.darkMode ? Theme.surface : "#FBFCFE"

    readonly property var categories: [
        { title: "设备信息", subtitle: "获取设备基础信息", icon: "smartphone", count: 4 },
        { title: "应用管理", subtitle: "安装、卸载、清理应用", icon: "apps", count: 6 },
        { title: "日志抓取", subtitle: "系统与应用日志", icon: "article", count: 5 },
        { title: "网络调试", subtitle: "网络状态与抓包调试", icon: "language", count: 4 },
        { title: "性能分析", subtitle: "CPU、内存、帧率分析", icon: "monitoring", count: 5 },
        { title: "文件操作", subtitle: "设备文件管理", icon: "folder", count: 4 }
    ]

    readonly property var deviceTools: [
        { title: "查看设备基本信息", subtitle: "获取设备的品牌、型号、Android 版本等信息", icon: "smartphone" },
        { title: "查看电池信息", subtitle: "获取电池状态、电量、温度等信息", icon: "battery_full" },
        { title: "查看屏幕信息", subtitle: "获取屏幕分辨率、密度、刷新率等信息", icon: "phone_android" },
        { title: "查看存储信息", subtitle: "获取存储空间使用情况", icon: "storage" }
    ]

    readonly property var commands: [
        "adb shell getprop ro.product.brand",
        "adb shell getprop ro.product.model",
        "adb shell getprop ro.product.device",
        "adb shell getprop ro.build.version.release",
        "adb shell getprop ro.build.version.sdk"
    ]

    Text {
        x: 28; y: 1
        text: "预设"
        color: Theme.textPrimary
        font.pixelSize: 28
        font.weight: Font.Bold
    }
    Text {
        x: 28; y: 47
        text: "快速调用常用调试方案"
        color: Theme.textSecondary
        font.pixelSize: 14
    }

    TextField {
        id: searchField
        x: parent.width - 422; y: 12; width: 390; height: 46
        leftPadding: 38; rightPadding: 14
        placeholderText: "搜索预设名称或描述..."
        text: root.searchQuery
        color: Theme.textPrimary
        font.pixelSize: 13
        onTextChanged: if (root.searchQuery !== text) root.searchEdited(text)
        background: Rectangle {
            radius: 10
            color: Theme.surfaceContainerLow
            border.color: searchField.activeFocus ? Theme.primary : Theme.outline
            border.width: 1
            MaterialIcon { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; icon: "search"; iconSize: 18; color: Theme.textSecondary }
        }
    }

    Rectangle {
        id: leftPanel
        x: 28; y: 84; width: 350; height: parent.height - 113
        radius: 12
        color: Theme.surfaceContainerLow
        border.color: Theme.darkMode ? Theme.outlineVariant : "#E0E4EA"
        border.width: 1
        clip: true

        Column {
            x: 10; y: 10; width: 330; spacing: 8
            Repeater {
                model: root.categories
                delegate: Rectangle {
                    id: categoryRow
                    required property var modelData
                    required property int index
                    width: 330; height: 68; radius: 10
                    color: root.selectedCategory === index
                        ? (Theme.darkMode ? Theme.primaryContainer : "#DCEBFF")
                        : (categoryMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 12
                        MaterialIcon { Layout.preferredWidth: 24; icon: categoryRow.modelData.icon; iconSize: 24; color: root.selectedCategory === categoryRow.index ? Theme.primary : Theme.secondary }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: categoryRow.modelData.title; color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { text: categoryRow.modelData.subtitle; color: Theme.textSecondary; font.pixelSize: 11 }
                        }
                        Text { text: categoryRow.modelData.count; color: Theme.textSecondary; font.pixelSize: 12 }
                        MaterialIcon { icon: "chevron_right"; iconSize: 16; color: Theme.textSecondary }
                    }
                    MouseArea { id: categoryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedCategory = categoryRow.index; root.selectedTool = 0 } }
                }
            }
        }
        Rectangle { x: 10; y: 465; width: 330; height: 1; color: Theme.outlineVariant }
        Text {
            x: 10; y: 475
            text: root.categories[root.selectedCategory].title + "（" + root.categories[root.selectedCategory].count + "）"
            color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold
        }
        Column {
            x: 10; y: 501; width: 330; spacing: 8
            Repeater {
                model: root.deviceTools
                delegate: Rectangle {
                    id: toolRow
                    required property var modelData
                    required property int index
                    width: 330; height: 60; radius: 9
                    color: root.selectedTool === index
                        ? (Theme.darkMode ? Theme.primaryContainer : "#DCEBFF")
                        : (toolMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        MaterialIcon { Layout.preferredWidth: 22; icon: toolRow.modelData.icon; iconSize: 20; color: root.selectedTool === toolRow.index ? Theme.primary : Theme.secondary }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: toolRow.modelData.title; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: toolRow.modelData.subtitle; color: Theme.textSecondary; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                    MouseArea { id: toolMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedTool = toolRow.index }
                }
            }
        }
    }

    Rectangle {
        id: detailPanel
        x: 396; y: 84; width: parent.width - 428; height: parent.height - 113
        radius: 12
        color: Theme.surfaceContainerLow
        border.color: Theme.darkMode ? Theme.outlineVariant : "#E0E4EA"
        border.width: 1
        clip: true

        Rectangle {
            x: 17; y: 27; width: 56; height: 56; radius: 10
            color: Theme.darkMode ? Theme.primaryContainer : "#DCEBFF"
            MaterialIcon { anchors.centerIn: parent; icon: root.deviceTools[root.selectedTool].icon; iconSize: 28; color: Theme.primary }
        }
        Text {
            x: 87; y: 29; width: parent.width - 240
            text: root.deviceTools[root.selectedTool].title
            color: Theme.textPrimary; font.pixelSize: 22; font.weight: Font.Bold; elide: Text.ElideRight
        }
        Text {
            x: 87; y: 62; width: parent.width - 240
            text: root.deviceTools[root.selectedTool].subtitle
            color: Theme.textSecondary; font.pixelSize: 13; elide: Text.ElideRight
        }
        Rectangle {
            x: parent.width - 102; y: 34; width: 84; height: 42; radius: 9
            color: favoriteMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.color: Theme.outline
            Row {
                anchors.centerIn: parent
                spacing: 7
                MaterialIcon { icon: root.favorite ? "star" : "star_border"; iconSize: 19; color: root.favorite ? Theme.primary : Theme.secondary }
                Text { text: "收藏"; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            MouseArea { id: favoriteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.favorite = !root.favorite }
        }
        Rectangle { x: 17; y: 105; width: parent.width - 35; height: 1; color: Theme.outlineVariant }

        Text { x: 17; y: 123; text: "参数配置"; color: Theme.textPrimary; font.pixelSize: 17; font.weight: Font.DemiBold }
        Text { x: 17; y: 172; text: "输出格式"; color: Theme.textPrimary; font.pixelSize: 13 }
        AppComboBox { x: 87; y: 159; width: 550; height: 40; model: ["标准输出（默认）", "JSON 格式", "仅显示值"]; font.pixelSize: 13 }
        Text { x: 17; y: 218; text: "信息类型"; color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.Medium }
        Column {
            x: 17; y: 238; spacing: 6
            PresetCheckRow { text: "基本信息（品牌、型号、系统版本）"; checked: root.includeBasic; onToggled: function(value) { root.includeBasic = value } }
            PresetCheckRow { text: "硬件信息（CPU、内存）"; checked: root.includeHardware; onToggled: function(value) { root.includeHardware = value } }
            PresetCheckRow { text: "系统属性"; checked: root.includeSystem; onToggled: function(value) { root.includeSystem = value } }
            PresetCheckRow { text: "显示构建信息（Build）"; checked: root.includeBuild; onToggled: function(value) { root.includeBuild = value } }
        }
        Text { x: 17; y: 385; text: "设备选择"; color: Theme.textPrimary; font.pixelSize: 13 }
        Rectangle {
            x: 87; y: 372; width: 520; height: 40; radius: 8
            color: Theme.surfaceContainerLow; border.color: Theme.outline
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                Text { Layout.fillWidth: true; text: root.androidBackend.selectedAndroidDevice.length > 0 ? root.androidBackend.selectedAndroidDeviceLabel : "当前连接的设备（默认）"; color: Theme.textPrimary; font.pixelSize: 13; elide: Text.ElideMiddle }
                MaterialIcon { icon: "expand_more"; iconSize: 17; color: Theme.textSecondary }
            }
        }
        Rectangle {
            x: 17; y: 428; width: parent.width - 35; height: 210; radius: 10
            color: Theme.darkMode ? Theme.surfaceContainer : "#F7F8FA"
            Text { x: 14; y: 14; text: "命令预览"; color: Theme.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }
            Column {
                x: 14; y: 45; spacing: 8
                Repeater {
                    model: root.commands
                    delegate: Row {
                        required property string modelData
                        required property int index
                        spacing: 15
                        Text { width: 10; text: String(index + 1); color: Theme.primary; font.pixelSize: 13 }
                        Text { text: modelData; color: Theme.primary; font.pixelSize: 13 }
                    }
                }
            }
        }
        Row {
            x: 17; y: 652; spacing: 12
            Rectangle {
                width: 260; height: 48; radius: 9
                color: runMouse.containsMouse ? Theme.primaryHover : Theme.primary
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialIcon { icon: "play_arrow"; iconSize: 20; color: "white" }
                    Text { text: "运行"; color: "white"; font.pixelSize: 14; font.weight: Font.DemiBold }
                }
                MouseArea { id: runMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.appendConsoleMessage("已运行预设：" + root.deviceTools[root.selectedTool].title + "\n") }
            }
            Rectangle {
                width: 240; height: 48; radius: 9
                color: favoriteBottomMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
                border.color: Theme.outline
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialIcon { icon: root.favorite ? "star" : "star_border"; iconSize: 18; color: Theme.secondary }
                    Text { text: "收藏"; color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold }
                }
                MouseArea { id: favoriteBottomMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.favorite = !root.favorite }
            }
            Rectangle {
                width: 240; height: 48; radius: 9
                color: copyMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
                border.color: Theme.outline
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialIcon { icon: "content_copy"; iconSize: 18; color: Theme.secondary }
                    Text { text: "复制命令"; color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold }
                }
                MouseArea { id: copyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { clipboardBuffer.selectAll(); clipboardBuffer.copy(); clipboardBuffer.deselect() } }
            }
        }
        TextArea { id: clipboardBuffer; visible: false; text: root.commands.join("\n") }
    }
}
