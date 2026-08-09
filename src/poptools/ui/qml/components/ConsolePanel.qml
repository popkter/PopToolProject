import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    required property var controller
    property color panelColor: Theme.middlePanel
    property bool expanded: true
    property real defaultExpandedHeight: 292
    property real expandedHeight: minimumExpandedHeight
    property bool userResized: false
    property real minimumExpandedHeight: 128
    property real maximumExpandedHeight: Math.max(minimumExpandedHeight,
                                                   Math.min(640, parent ? parent.height - 100 : 640))
    property real resizeStartSceneY: 0
    property real resizeStartHeight: 0

    clip: true

    implicitHeight: root.expanded ? root.expandedHeight : 82

    function clampedHeight(value) {
        return Math.max(minimumExpandedHeight, Math.min(maximumExpandedHeight, value))
    }

    function applyDefaultHeight() {
        expandedHeight = clampedHeight(defaultExpandedHeight)
    }

    Component.onCompleted: applyDefaultHeight()
    onDefaultExpandedHeightChanged: {
        if (!userResized)
            applyDefaultHeight()
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
        height: 20
        color: root.panelColor

        MouseArea {
            id: resizeMouse
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
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
                root.expandedHeight = Math.max(root.minimumExpandedHeight,
                                               Math.min(root.maximumExpandedHeight, requestedHeight))
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        // Normal mode keeps the original anchors.topMargin: 20 spacing.
        anchors.topMargin: 20

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10

            Text {
                text: "运行数据"
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
            Layout.margins: 12
            Layout.topMargin: 0
            radius: 14
            color: Theme.consoleBackground

            ScrollView {
                anchors.fill: parent
                anchors.margins: 14
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
                    background: null
                    onTextChanged: cursorPosition = length
                }
            }
        }
    }
}









