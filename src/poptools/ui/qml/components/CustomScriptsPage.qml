pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    objectName: "customScriptsPage"
    required property var controller
    required property var androidBackend
    required property var parentWindow
    required property var parameterValues
    property string searchQuery: ""
    property bool compact: false
    property bool compactHeight: false
    property bool overlaysVisible: false
    property string kindFilter: "all"
    readonly property bool drawerVisible: false
    readonly property bool popupVisible: false
    color: Theme.darkMode ? Theme.surface : "#FBFCFE"

    signal searchEdited(string query)
    signal createRequested()
    signal importRequested()
    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal toastRequested(string message, bool error)

    function closeDrawerImmediately() {}
    function closeDrawer() {}

    component OutlineButton: Rectangle {
        id: button
        property string text: ""
        property string iconName: ""
        signal clicked()
        implicitWidth: labelRow.implicitWidth + 28
        implicitHeight: 34
        radius: Theme.radiusSmall
        color: buttonMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
        border.color: Theme.outline
        Row {
            id: labelRow; anchors.centerIn: parent; spacing: 8
            MaterialIcon { visible: button.iconName.length > 0; icon: button.iconName; iconSize: 18; color: Theme.textSecondary }
            Text { text: button.text; color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
        }
        MouseArea { id: buttonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
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
            title: "自定义"
            description: "管理与运行常用脚本"
            titlePixelSize: 28
            actionWidth: 209
            OutlineButton { Layout.preferredWidth: 78; Layout.preferredHeight: 34; text: "导入"; onClicked: root.importRequested() }
            PrimaryButton { Layout.preferredWidth: 116; Layout.preferredHeight: 34; text: "新建脚本"; iconName: "add"; onClicked: root.createRequested() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 338
                Layout.minimumWidth: 338
                Layout.maximumWidth: 338
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space16
                    spacing: 10

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        leftPadding: 42
                        rightPadding: 14
                        placeholderText: "搜索名称、说明或标签..."
                        text: root.searchQuery
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBody
                        onTextChanged: if (root.searchQuery !== text) root.searchEdited(text)
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: Theme.surfaceContainer
                            border.color: searchField.activeFocus ? Theme.primary : "transparent"
                            border.width: searchField.activeFocus ? 1 : 0
                            MaterialIcon { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; icon: "search"; iconSize: 20; color: Theme.textSecondary }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "全部", value: "all" },
                                { label: "ADB", value: "batch" },
                                { label: "PowerShell", value: "powershell" },
                                { label: "Python", value: "python" },
                            ]
                            delegate: Rectangle {
                                id: filterChip
                                required property var modelData
                                width: filterChip.modelData.value === "powershell" ? 95
                                    : filterChip.modelData.value === "python" ? 69
                                    : filterChip.modelData.value === "all" ? 52 : 54
                                height: 28
                                radius: Theme.radiusSmall
                                color: root.kindFilter === modelData.value ? Theme.primaryContainer : Theme.surfaceContainerLow
                                border.color: root.kindFilter === modelData.value ? Theme.primary : Theme.outline
                                Text { anchors.centerIn: parent; text: filterChip.modelData.label; color: root.kindFilter === filterChip.modelData.value ? Theme.primary : Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.kindFilter = filterChip.modelData.value }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.topMargin: 3
                        Text { Layout.fillWidth: true; Layout.leftMargin: 8; text: "脚本名称"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        Text { text: "类型"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption; Layout.rightMargin: 61 }
                    }

                    ListView {
                        id: scriptList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        Layout.leftMargin: -8
                        Layout.rightMargin: -8
                        spacing: 0
                        model: root.controller.toolsModel
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: scriptRow
                            required property string toolId
                            required property string title
                            required property string description
                            required property string iconName
                            required property string executorKind
                            required property bool selected
                            required property bool running
                            required property int index
                            width: scriptList.width
                            height: (root.kindFilter === "all" || root.kindFilter === "favorite" || root.kindFilter === executorKind) ? 40 : 0
                            visible: height > 0
                            radius: 6
                            color: selected ? (Theme.darkMode ? Theme.primaryContainer : "#E5F0FF")
                                : (rowMouse.containsMouse ? Theme.surfaceContainer
                                : (index % 2 === 0 ? (Theme.darkMode ? "transparent" : "#FAFBFC") : "transparent"))
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 5
                                    color: scriptRow.executorKind === "python" ? Theme.tertiaryContainer : scriptRow.executorKind === "powershell" ? Theme.primaryContainer : Theme.successContainer
                                    MaterialIcon { anchors.centerIn: parent; icon: scriptRow.executorKind === "batch" ? "smartphone" : "terminal"; iconSize: 16; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.primary : Theme.success }
                                }
                                Text { Layout.fillWidth: true; text: scriptRow.title; color: scriptRow.selected ? Theme.primary : Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: scriptRow.selected ? Font.Bold : Font.Normal; elide: Text.ElideRight }
                                Rectangle {
                                    Layout.preferredWidth: 94; Layout.preferredHeight: 22; radius: 4
                                    color: scriptRow.executorKind === "python" ? Theme.tertiaryContainer : scriptRow.executorKind === "powershell" ? Theme.primaryContainer : Theme.successContainer
                                    Text { id: kindLabel; anchors.centerIn: parent; text: scriptRow.executorKind === "batch" ? "ADB" : scriptRow.executorKind === "powershell" ? "PowerShell" : scriptRow.executorKind === "python" ? "Python" : scriptRow.executorKind; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.primary : Theme.success; font.pixelSize: Theme.fontCaption }
                                }
                                MaterialIcon { icon: "chevron_right"; iconSize: 19; color: scriptRow.selected ? Theme.primary : Theme.textSecondary }
                            }
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.selectTool(scriptRow.toolId) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        Text { Layout.fillWidth: true; text: scriptList.count + " 个脚本"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        Text { text: "紧凑 · ↑↓ 切换"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        ToolSortButton { Layout.preferredWidth: 24; Layout.preferredHeight: 24; controller: root.controller }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant
                border.width: 1
                clip: true

                CustomToolDetailPanel {
                    anchors.fill: parent
                    controller: root.controller
                    androidBackend: root.androidBackend
                    parentWindow: root.parentWindow
                    parameterValues: root.parameterValues
                    displayedTool: root.controller.selectedTool
                    onEditRequested: root.editRequested()
                    onDeleteRequested: root.deleteRequested()
                    onConfirmRunRequested: function(values) { root.confirmRunRequested(values) }
                    onToastRequested: function(message, error) { root.toastRequested(message, error) }
                }
            }
        }
    }
}
