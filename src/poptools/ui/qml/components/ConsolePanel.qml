import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    required property var controller
    required property int minimumVisibleLineCount
    required property real preferredExpandedHeight
    required property real maximumExpandedHeight
    required property bool resizable
    property color panelColor: Theme.middlePanel
    property bool expanded: true
    property real expandedHeight: minimumExpandedHeight
    property bool userResized: false
    property real resizeStartSceneY: 0
    property real resizeStartHeight: 0
    property real panelMargin: 0
    readonly property real separatorHeight: 20
    readonly property real headerHeight: 62
    readonly property real outputOuterMargin: 16
    readonly property real outputViewportMargin: 14
    readonly property real outputTextVerticalPadding: 12
    readonly property real minimumExpandedHeight:
        separatorHeight + headerHeight + outputOuterMargin
            + outputViewportMargin * 2 + outputTextVerticalPadding
            + Math.ceil(consoleFontMetrics.lineSpacing * minimumVisibleLineCount)
    readonly property real dragMinimumExpandedHeight: root.resizable
        ? Math.max(minimumExpandedHeight,
                   Math.min(maximumExpandedHeight, preferredExpandedHeight))
        : minimumExpandedHeight
    readonly property real collapsedHeight: separatorHeight + headerHeight

    FontMetrics {
        id: consoleFontMetrics
        font.family: "Cascadia Mono"
        font.pixelSize: 13
    }

    clip: true

    implicitHeight: !root.resizable
        ? root.clampedHeight(root.preferredExpandedHeight)
        : (root.expanded ? root.expandedHeight : root.collapsedHeight)

    function clampedHeight(value) {
        return Math.max(dragMinimumExpandedHeight,
                        Math.min(maximumExpandedHeight, value))
    }

    function applyDefaultHeight() {
        expandedHeight = clampedHeight(preferredExpandedHeight)
    }

    Component.onCompleted: applyDefaultHeight()
    onResizableChanged: {
        userResized = false
        expanded = true
        applyDefaultHeight()
    }
    onPreferredExpandedHeightChanged: {
        if (!userResized)
            applyDefaultHeight()
    }
    onDragMinimumExpandedHeightChanged: {
        if (userResized)
            expandedHeight = clampedHeight(expandedHeight)
    }
    onMaximumExpandedHeightChanged: {
        if (userResized)
            expandedHeight = clampedHeight(expandedHeight)
        else
            applyDefaultHeight()
    }

    Connections {
        target: root.controller
        function onSelectedToolChanged() {
            root.userResized = false
            Qt.callLater(root.applyDefaultHeight)
        }
    }

    Rectangle {
        id: resizeSeparator
        visible: true
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.separatorHeight
        color: root.panelColor

        MouseArea {
            id: resizeMouse
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 16
            enabled: root.resizable
            hoverEnabled: true
            cursorShape: root.resizable ? Qt.SizeVerCursor : Qt.ArrowCursor
            onPressed: function(mouse) {
                if (!root.expanded)
                    root.expanded = true
                root.userResized = true
                const scenePoint = resizeMouse.mapToItem(null, mouse.x, mouse.y)
                root.resizeStartSceneY = scenePoint.y
                root.resizeStartHeight = root.expandedHeight
            }
            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                const scenePoint = resizeMouse.mapToItem(null, mouse.x, mouse.y)
                const requestedHeight = root.resizeStartHeight
                                      + root.resizeStartSceneY - scenePoint.y
                root.expandedHeight = root.clampedHeight(requestedHeight)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: root.separatorHeight

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10

            Text {
                text: "控制台输出"
                color: Theme.textPrimary
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            MaterialIcon {
                icon: root.expanded ? "expand_more" : "expand_less"
                iconSize: 22
                color: Theme.textSecondary
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 86
                Layout.preferredHeight: 38
                radius: 10
                color: clearMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surface
                border.color: Theme.outlineVariant
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    MaterialIcon { icon: "delete"; iconSize: 19; color: Theme.textSecondary }
                    Text { text: "清空"; font.pixelSize: 14; color: Theme.textSecondary }
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.controller.clearConsole()
                }
            }
            Rectangle {
                visible: root.resizable
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: toggleMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.expanded ? "keyboard_arrow_down" : "keyboard_arrow_up"
                    iconSize: 23
                }
                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }
        }



        Rectangle {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root.outputOuterMargin
            Layout.rightMargin: root.outputOuterMargin
            Layout.bottomMargin: root.outputOuterMargin
            Layout.topMargin: 0
            radius: 14
            color: Theme.consoleBackground

            ScrollView {
                anchors.fill: parent
                anchors.margins: root.outputViewportMargin
                clip: true
                TextArea {
                    text: root.controller.consoleText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    color: Theme.consoleText
                    selectionColor: Theme.primary
                    selectedTextColor: "white"
                    font.family: "Cascadia Mono"
                    font.pixelSize: 13
                    topPadding: root.outputTextVerticalPadding / 2
                    bottomPadding: root.outputTextVerticalPadding / 2
                    background: null
                    onTextChanged: cursorPosition = length
                }
            }
        }
    }
}




