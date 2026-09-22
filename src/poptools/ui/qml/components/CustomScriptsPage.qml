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
    color: Theme.workspaceBackground

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
        implicitHeight: Theme.controlHeightSmall
        radius: Theme.radiusSmall
        tonal: true
        color: hovered ? Theme.surfaceContainer : Theme.surfaceContainerLow
        border.color: Theme.outline
        foregroundColor: Theme.textPrimary
        labelFontSize: Theme.fontSupporting
        glyphSize: 18
        contentSpacing: 8
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.workspaceInset
        anchors.rightMargin: Theme.workspaceInset
        anchors.topMargin: 0
        anchors.bottomMargin: Theme.workspaceInset
        spacing: Theme.space16

        WorkspacePageHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.pageHeaderHeight
            Layout.minimumHeight: Theme.pageHeaderHeight
            Layout.maximumHeight: Theme.pageHeaderHeight
            title: "自定义"
            description: "管理与运行常用脚本"
            titlePixelSize: Theme.workspaceTitleSize
            actionWidth: 210
            OutlineButton { Layout.preferredWidth: 78; Layout.preferredHeight: Theme.controlHeightSmall; text: "导入"; iconName: ""; onClicked: root.importRequested() }
            PrimaryButton { Layout.preferredWidth: 116; Layout.preferredHeight: Theme.controlHeightSmall; text: "新建脚本"; iconName: "add"; onClicked: root.createRequested() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.scriptPanelGap

            Rectangle {
                objectName: "customScriptListPanel"
                Layout.preferredWidth: Math.max(Theme.scriptListMinimumWidth, Math.min(Theme.scriptListMaximumWidth, (root.width - Theme.workspaceInset * 2) * Theme.scriptListWidthRatio))
                Layout.minimumWidth: Theme.scriptListMinimumWidth
                Layout.maximumWidth: Theme.scriptListMaximumWidth
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space16
                    spacing: Theme.space8

                    AppTextField {
                        id: searchField
                        FilePathDropArea { target: searchField }
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        leftPadding: 42
                        rightPadding: 14
                        placeholderText: "搜索名称、说明或标签..."
                        text: root.searchQuery
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSupporting
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
                                border.color: root.kindFilter === modelData.value ? Theme.listSelected : Theme.outline
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
                            Layout.leftMargin: 0
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
                                text: ""
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

                    }

                    ListView {
                        id: scriptList
                        function selectAdjacent(direction) {
                            const toolId = model.adjacentToolId(direction, root.kindFilter)
                            if (toolId.length > 0) root.controller.selectTool(toolId)
                        }
                        Keys.onUpPressed: selectAdjacent(-1)
                        Keys.onDownPressed: selectAdjacent(1)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        Layout.leftMargin: 0
                        Layout.rightMargin: 0
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
                            onSelectedChanged: if (selected) scriptList.positionViewAtIndex(index, ListView.Contain)
                            width: scriptList.width - (scriptListScrollBar.visible
                                ? scriptListScrollBar.width + Theme.space8 : 0)

                            height: (root.kindFilter === "all" || root.kindFilter === "favorite" || root.kindFilter === executorKind) ? Theme.scriptRowHeight : 0
                            visible: height > 0
                            radius: Theme.radiusControl
                            color: selected ? (Theme.listSelected)
                                : (rowMouse.containsMouse ? Theme.surfaceContainer
                                : (index % 2 === 0 ? (Theme.listAlternate) : "transparent"))
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: Theme.space12; anchors.rightMargin: Theme.space8; spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 5
                                    color: scriptRow.executorKind === "python" ? Theme.tertiaryContainer : scriptRow.executorKind === "powershell" ? Theme.runtimeBadge : Theme.successContainer
                                    MaterialIcon { anchors.centerIn: parent; icon: scriptRow.iconName || (scriptRow.executorKind === "batch" ? "smartphone" : "terminal"); iconSize: 16; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.runtimeBadgeText : Theme.success }
                                }
                                Text { Layout.fillWidth: true; text: scriptRow.title; color: scriptRow.selected ? Theme.primary : Theme.textPrimary; font.pixelSize: Theme.fontSupporting; font.weight: scriptRow.selected ? Font.Bold : Font.Normal; elide: Text.ElideRight }
                                Rectangle {
                                    Layout.preferredWidth: root.scriptKindColumnWidth; Layout.preferredHeight: 22; radius: Theme.radiusTiny
                                    color: scriptRow.executorKind === "python" ? Theme.tertiaryContainer : scriptRow.executorKind === "powershell" ? Theme.runtimeBadge : Theme.successContainer
                                    Text { id: kindLabel; anchors.centerIn: parent; text: scriptRow.executorKind === "batch" ? "ADB" : scriptRow.executorKind === "powershell" ? "PowerShell" : scriptRow.executorKind === "python" ? "Python" : scriptRow.executorKind; color: scriptRow.executorKind === "python" ? Theme.tertiary : scriptRow.executorKind === "powershell" ? Theme.runtimeBadgeText : Theme.success; font.pixelSize: Theme.fontSmall }
                                }
                                MaterialIcon { icon: "chevron_right"; iconSize: 14; color: Theme.textSecondary; Layout.preferredWidth: 14 }
                            }
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.controller.selectTool(scriptRow.toolId); scriptList.forceActiveFocus() } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: scriptList.count + " 个脚本"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
                        Text { text: "紧凑 · ↑↓ 切换"; color: Theme.textSecondary; font.pixelSize: Theme.fontCaption }
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
