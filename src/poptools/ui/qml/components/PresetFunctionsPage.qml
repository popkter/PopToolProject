pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
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
    readonly property real effectiveToolListWidth:
        Math.min(root.toolListWidth, Theme.navigationMaximumWidth)
    readonly property real headerHeight: compactHeight ? 56 : 68
    readonly property real workspaceTop:
        (compact ? Theme.pagePaddingCompact : Theme.pagePadding)
        + headerHeight + Theme.space12
    readonly property bool popupVisible: compactSearchPopup.visible
    readonly property bool scrcpySelected:
        controller.selectedTool.workspace === "scrcpy"
    readonly property bool recordingSelected:
        !!controller.selectedTool.executor
        && controller.selectedTool.executor.command === "recording"
    readonly property bool internalPresetSelected:
        controller.selectedTool.workspace === "preset"

    signal searchEdited(string query)
    signal confirmRunRequested(var values)

    WorkspacePageHeader {
        id: pageHeader
        x: Theme.space12
        y: root.compactHeight ? Theme.pagePaddingCompact : Theme.pagePadding
        width: parent.width - x
            - (root.compact ? Theme.pagePaddingCompact : Theme.pagePadding)
        height: root.headerHeight
        compact: root.compactHeight
        title: "预设功能"
        description: "选择内置工具，配置参数并查看运行信息"
    }

    Rectangle {
        id: toolPanel
        anchors.left: parent.left
        anchors.leftMargin: Theme.space12
        anchors.top: parent.top
        anchors.topMargin: root.workspaceTop
        anchors.bottom: parent.bottom
        width: Math.max(0, root.effectiveToolListWidth - anchors.leftMargin)
        radius: Theme.radiusLarge
        color: Theme.middlePanel
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(Theme.radiusLarge, parent.height)
            color: parent.color
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.compact
                ? Theme.pagePaddingCompact : Theme.pagePadding
            anchors.rightMargin: root.compact
                ? Theme.pagePaddingCompact : Theme.pagePadding
            anchors.topMargin: root.compactToolList || root.compactHeight
                ? Theme.panelPaddingCompact : Theme.panelPadding
            anchors.bottomMargin: root.compactToolList || root.compactHeight
                ? Theme.panelPaddingCompact : Theme.panelPadding
            spacing: root.compactHeight
                ? Theme.controlSpacing : Theme.sectionSpacing

            Item {
                visible: root.compactToolList
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Rectangle {
                    id: compactSearchButton
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: height / 2
                    color: compactSearchMouse.containsMouse
                        ? Theme.primaryContainerHover : Theme.surface
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "search"
                        iconSize: 24
                        color: Theme.primary
                    }
                    ToolTip.visible: compactSearchMouse.containsMouse
                    ToolTip.text: "搜索工具"
                    ToolTip.delay: 450
                    MouseArea {
                        id: compactSearchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const point = compactSearchButton.mapToItem(
                                Overlay.overlay, compactSearchButton.width / 2,
                                compactSearchButton.height + Theme.space8)
                            compactSearchPopup.x = Math.max(
                                Theme.space12,
                                Math.min(point.x - compactSearchPopup.width / 2,
                                    Overlay.overlay.width - compactSearchPopup.width
                                    - Theme.space12))
                            compactSearchPopup.y = Math.max(
                                Theme.space12,
                                Math.min(point.y,
                                    Overlay.overlay.height - compactSearchPopup.height
                                    - Theme.space12))
                            compactSearchPopup.open()
                            Qt.callLater(function() {
                                compactSearchField.forceActiveFocus()
                                compactSearchField.selectAll()
                            })
                        }
                    }
                }
            }

            TextField {
                id: searchField
                visible: !root.compactToolList
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                leftPadding: Theme.space40
                rightPadding: Theme.space16
                placeholderText: "搜索工具"
                text: root.searchQuery
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                onTextChanged: {
                    if (root.searchQuery !== text)
                        root.searchEdited(text)
                }
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surface
                    border.color: searchField.activeFocus
                        ? Theme.primary : Theme.outline
                    border.width: searchField.activeFocus
                        ? Theme.borderWidthMedium : Theme.borderWidthThin
                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "search"
                        iconSize: 24
                        color: Theme.textSecondary
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: toolList
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.space4
                    model: root.controller.toolsModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: toolDelegate
                        required property string toolId
                        required property string title
                        required property string iconName
                        required property bool selected
                        required property bool running
                        width: toolList.width
                        height: 64
                        ToolListItem {
                            anchors.fill: parent
                            title: parent.title
                            iconName: parent.iconName
                            selected: parent.selected
                            running: parent.running
                            foregroundColor: Theme.textPrimary
                            hoverColor: Theme.surfaceContainerHigh
                            compact: root.compactToolList
                            onClicked: root.controller.selectTool(parent.toolId)
                        }
                    }
                }

                ScrollBar {
                    id: toolScrollBar
                    orientation: Qt.Vertical
                    anchors.left: parent.right
                    anchors.leftMargin: Theme.space4
                    anchors.top: toolList.top
                    anchors.bottom: toolList.bottom
                    size: toolList.visibleArea.heightRatio
                    policy: ScrollBar.AsNeeded
                    active: toolList.movingVertically || toolList.flickingVertically
                    Connections {
                        target: toolList
                        function onContentYChanged() {
                            if (!toolScrollBar.pressed)
                                toolScrollBar.position = toolList.visibleArea.yPosition
                        }
                    }
                    onPositionChanged: {
                        if (pressed)
                            toolList.contentY = position * toolList.contentHeight
                    }
                }
            }
        }
    }

    Popup {
        id: compactSearchPopup
        parent: Overlay.overlay
        width: Math.min(320, Overlay.overlay.width - Theme.space24)
        height: 72
        padding: Theme.space12
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: AppPopupSurface { }
        contentItem: TextField {
            id: compactSearchField
            placeholderText: "搜索工具"
            text: root.searchQuery
            leftPadding: Theme.space40
            rightPadding: Theme.space16
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            onTextChanged: {
                if (root.searchQuery !== text)
                    root.searchEdited(text)
            }
            background: Rectangle {
                radius: Theme.radiusMedium
                color: Theme.surface
                border.color: compactSearchField.activeFocus
                    ? Theme.primary : Theme.outline
                border.width: compactSearchField.activeFocus
                    ? Theme.borderWidthMedium : Theme.borderWidthThin
                MaterialIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    iconSize: 24
                    color: Theme.textSecondary
                }
            }
        }
    }

    ToolDetailPanel {
        id: detailPanel
        x: root.effectiveToolListWidth
        y: root.workspaceTop
        width: parent.width - root.effectiveToolListWidth
        height: parent.height - y
        controller: root.controller
        parentWindow: root.parentWindow
        parameterValues: root.parameterValues
        displayedTool: root.controller.selectedTool
        presetUtilities: root.presetUtilities
        androidBackend: root.androidBackend
        jiraFeishuBackend: root.jiraFeishuBackend
        compact: root.compact
        compactHeight: root.compactHeight
        overlaysVisible: root.overlaysVisible
        internalPresetSelected: root.internalPresetSelected
        scrcpySelected: root.scrcpySelected
        recordingSelected: root.recordingSelected
        onConfirmRunRequested: function(values) {
            root.confirmRunRequested(values)
        }
    }
}
