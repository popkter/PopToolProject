pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    objectName: "customScriptsPage"

    required property var controller
    required property var parentWindow
    required property var parameterValues
    property string searchQuery: ""
    property bool compact: false
    property bool compactHeight: false
    property bool overlaysVisible: false
    property bool gridReady: false
    property bool drawerClosing: false
    property var drawerTool: ({})
    readonly property bool drawerVisible: root.visible
        && root.controller.selectedTool.section === "custom"
        && !!root.controller.selectedTool.id && !root.drawerClosing

    signal searchEdited(string query)
    signal createRequested()
    signal importRequested()
    signal editRequested()
    signal deleteRequested()
    signal confirmRunRequested(var values)
    signal toastRequested(string message, bool error)

    function prepareGrid() {
        root.gridReady = false
        if (!root.controller.toolsReady)
            return
        Qt.callLater(function() {
            root.gridReady = true
            gridRelayoutTimer.restart()
        })
    }

    function openDrawer(toolId) {
        root.drawerClosing = false
        root.controller.selectTool(toolId)
    }

    function closeDrawer() {
        if (root.controller.selectedTool.section === "custom"
                && !!root.controller.selectedTool.id)
            root.drawerClosing = true
    }

    function closeDrawerImmediately() {
        root.drawerClosing = false
        root.controller.clearToolSelection()
    }

    function cacheDrawerTool() {
        const tool = root.controller.selectedTool
        if (tool.section === "custom" && !!tool.id)
            root.drawerTool = tool
    }

    Component.onCompleted: prepareGrid()
    onWidthChanged: {
        if (root.gridReady)
            gridRelayoutTimer.restart()
    }

    Connections {
        target: root.controller
        function onSelectedToolChanged() {
            root.cacheDrawerTool()
            if (root.controller.selectedTool.section !== "custom")
                root.drawerClosing = false
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: root.drawerVisible && !root.overlaysVisible
        onActivated: root.closeDrawer()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space12
            anchors.rightMargin: root.compact
                ? Theme.pagePaddingCompact : Theme.pagePadding
            anchors.topMargin: root.compact
                ? Theme.pagePaddingCompact : Theme.pagePadding
            anchors.bottomMargin: root.compact
                ? Theme.pagePaddingCompact : Theme.pagePadding
            spacing: Theme.sectionSpacing

            WorkspacePageHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compactHeight ? 56 : 68
                compact: root.compactHeight
                title: "客制脚本"
                description: "选择脚本以查看参数、运行状态和输出"
                actionWidth: 144

                ToolSortButton {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    controller: root.controller
                    foregroundColor: Theme.tertiary
                    backgroundColor: Theme.tertiaryContainer
                    hoverColor: Theme.tertiaryContainerHover
                }

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Theme.radiusMedium
                    color: importMouse.containsMouse
                        ? Theme.secondaryContainerHover : Theme.secondaryContainer
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "file_download"
                        iconSize: 24
                        color: Theme.secondary
                    }
                    AppToolTip {
                        visible: importMouse.containsMouse
                        text: "从剪贴板导入脚本"
                        delay: 450
                    }
                    MouseArea {
                        id: importMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.importRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Theme.radiusMedium
                    color: createMouse.containsMouse
                        ? Theme.primaryContainerHover : Theme.primaryContainer
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "add"
                        iconSize: 24
                        color: Theme.primary
                    }
                    AppToolTip {
                        visible: createMouse.containsMouse
                        text: "新建命令"
                        delay: 450
                    }
                    MouseArea {
                        id: createMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.createRequested()
                    }
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                leftPadding: Theme.space40
                rightPadding: Theme.space16
                placeholderText: "搜索脚本名称、说明或运行方式"
                text: root.searchQuery
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                onTextChanged: {
                    if (root.searchQuery !== text)
                        root.searchEdited(text)
                }
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: searchField.activeFocus
                        ? Theme.primary : Theme.outlineVariant
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

                GridView {
                    id: scriptGrid
                    readonly property int columnCount: Math.max(
                        1, Math.min(4, Math.floor(width / 240)))
                    readonly property real columnGap: Theme.space12
                    anchors.fill: parent
                    clip: true
                    visible: root.gridReady
                    model: root.gridReady && root.controller.toolsReady
                        ? root.controller.toolsModel : null
                    cellWidth: width / columnCount
                    cellHeight: 92
                    boundsBehavior: Flickable.StopAtBounds
                    onWidthChanged: {
                        if (root.gridReady)
                            gridRelayoutTimer.restart()
                    }
                    onColumnCountChanged: {
                        if (root.gridReady)
                            gridRelayoutTimer.restart()
                    }

                    delegate: Item {
                        id: scriptDelegate
                        required property int index
                        required property string toolId
                        required property string title
                        required property string description
                        required property string iconName
                        required property string executorKind
                        required property bool selected
                        required property bool running
                        readonly property int gridColumn:
                            index % scriptGrid.columnCount
                        width: scriptGrid.cellWidth
                        height: scriptGrid.cellHeight
                        z: scriptCard.dragging ? 10 : 0

                        ToolGridItem {
                            id: scriptCard
                            x: scriptDelegate.gridColumn * scriptGrid.columnGap
                                / scriptGrid.columnCount
                            width: parent.width - scriptGrid.columnGap
                                * (scriptGrid.columnCount - 1)
                                / scriptGrid.columnCount
                            anchors.verticalCenter: parent.verticalCenter
                            height: 80
                            title: parent.title
                            description: parent.description
                            iconName: parent.iconName
                            executorKind: parent.executorKind
                            selected: parent.selected
                            running: parent.running
                            draggable: root.controller.toolSortMode === "custom"
                                && root.searchQuery.length === 0
                            dragTarget: scriptDelegate
                            dragMinimumX: 0
                            dragMaximumX: Math.max(0,
                                scriptGrid.width - scriptDelegate.width)
                            dragMinimumY: 0
                            dragMaximumY: Math.max(0,
                                scriptGrid.contentHeight - scriptDelegate.height)
                            onClicked: root.openDrawer(parent.toolId)
                            onDragFinished: function(centerX, centerY) {
                                const column = Math.max(0, Math.min(
                                    scriptGrid.columnCount - 1,
                                    Math.floor(centerX / scriptGrid.cellWidth)))
                                const row = Math.max(0,
                                    Math.floor(centerY / scriptGrid.cellHeight))
                                const targetIndex = Math.max(0, Math.min(
                                    scriptGrid.count - 1,
                                    row * scriptGrid.columnCount + column))
                                root.controller.moveTool(parent.toolId, targetIndex)
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.space12
                    visible: root.gridReady && scriptGrid.count === 0
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: root.searchQuery ? "search_off" : "inventory_2"
                        iconSize: 44
                        color: Theme.textSecondary
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchQuery
                            ? "没有匹配的客制脚本" : "还没有客制脚本"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
    }

    Timer {
        id: gridRelayoutTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.gridReady && root.controller.toolsReady)
                scriptGrid.forceLayout()
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.drawerVisible
        radius: Theme.applicationRadius
        color: Qt.rgba(0, 0, 0, 0.28)
        z: 5
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeDrawer()
        }
    }

    ToolDetailPanel {
        id: detailPanel
        controller: root.controller
        parentWindow: root.parentWindow
        parameterValues: root.parameterValues
        displayedTool: root.drawerTool
        drawerMode: true
        drawerVisible: root.drawerVisible
        compact: root.compact
        compactHeight: root.compactHeight
        overlaysVisible: root.overlaysVisible
        x: parent.width + Theme.space12
        y: Theme.space12
        width: Math.min(700, Math.max(560, parent.width * 0.56))
        height: parent.height - Theme.space24
        z: 6
        onCloseRequested: root.closeDrawer()
        onDrawerClosed: {
            if (root.drawerClosing
                    && root.controller.selectedTool.section === "custom")
                root.controller.clearToolSelection()
            root.drawerClosing = false
        }
        onEditRequested: root.editRequested()
        onDeleteRequested: root.deleteRequested()
        onConfirmRunRequested: function(values) {
            root.confirmRunRequested(values)
        }
        onToastRequested: function(message, error) {
            root.toastRequested(message, error)
        }
    }
}
