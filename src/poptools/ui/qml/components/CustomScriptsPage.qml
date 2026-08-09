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
    readonly property real scriptKindColumnWidth: Math.max(
        76, Math.min(94, scriptList.width * 0.3))
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

    component OutlineButton: PrimaryButton {
        implicitHeight: 34
        radius: Theme.radiusSmall
        tonal: true
        color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
        border.color: Theme.outline
        foregroundColor: Theme.textPrimary
        labelFontSize: Theme.fontBody
        glyphSize: 18
        contentSpacing: 8
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
            OutlineButton { Layout.preferredWidth: 78; Layout.preferredHeight: 34; text: "导入"; iconName: "file_download"; onClicked: root.importRequested() }
            PrimaryButton { Layout.preferredWidth: 116; Layout.preferredHeight: 34; text: "新建脚本"; iconName: "add"; onClicked: root.createRequested() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            Rectangle {
                objectName: "customScriptListPanel"
                Layout.preferredWidth: Math.max(290, Math.min(338, root.width * 0.38))
                Layout.minimumWidth: 290
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
                        FilePathDropArea { target: searchField }
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
                                { label: "Batch", value: "batch" },
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
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.leftMargin: 38
                            text: "脚本名称"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontCaption
                        }
                        Item {
                            Layout.preferredWidth: root.scriptKindColumnWidth
                            Layout.preferredHeight: 24
                            Text {
                                anchors.left: parent.left
                                anchors.right: sortButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "类型"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontCaption
                                horizontalAlignment: Text.AlignHCenter
                            }
                            ToolSortButton {
                                id: sortButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 24
                                glyphSize: 20
                                controller: root.controller
                            }
                        }
/*                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            Text {
                                Layout.fillWidth: true; text: scriptList.count + " 个脚本"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption
                            }
                            // Text { text: "紧凑 · ↑↓ 切换"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }

                        }*/
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

                        ScrollBar.vertical: ScrollBar {
                            id: scriptListScrollBar
                            policy: scriptList.contentHeight > scriptList.height + 0.5
                                ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        }

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
                            width: scriptList.width - (scriptListScrollBar.visible
                                ? scriptListScrollBar.width + Theme.space8 : 0)

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
                                    MaterialIcon { anchors.centerIn: parent; icon: scriptRow.iconName || (scriptRow.executorKind === "batch" ? "smartphone" : "terminal"); iconSize: 16; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.primary : Theme.success }
                                }
                                Text { Layout.fillWidth: true; text: scriptRow.title; color: scriptRow.selected ? Theme.primary : Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: scriptRow.selected ? Font.Bold : Font.Normal; elide: Text.ElideRight }
                                Rectangle {
                                    Layout.preferredWidth: root.scriptKindColumnWidth; Layout.preferredHeight: 22; radius: 4
                                    color: scriptRow.executorKind === "python" ? Theme.tertiaryContainer : scriptRow.executorKind === "powershell" ? Theme.primaryContainer : Theme.successContainer
                                    Text { id: kindLabel; anchors.centerIn: parent; text: scriptRow.executorKind === "batch" ? "Batch" : scriptRow.executorKind === "powershell" ? "PowerShell" : scriptRow.executorKind === "python" ? "Python" : scriptRow.executorKind; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.primary : Theme.success; font.pixelSize: Theme.fontCaption }
                                }
                            }
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.selectTool(scriptRow.toolId) }
                        }
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
