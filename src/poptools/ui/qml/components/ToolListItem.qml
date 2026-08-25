import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    required property string title
    required property string iconName
    required property bool selected
    property bool running: false
    property color foregroundColor: Theme.textPrimary
    property color hoverColor: Theme.surfaceContainer
    property bool compact: false
    property bool draggable: false
    property Item dragTarget: null
    property real dragMinimumY: 0
    property real dragMaximumY: 0
    property bool dragging: false
    signal clicked()
    signal dragFinished(real centerY)

    implicitHeight: 64
    radius: Theme.radiusMedium
    color: selected ? Theme.primaryContainer
                    : (mouseArea.containsMouse || dragging ? root.hoverColor : "transparent")
    border.color: dragging ? Theme.primary : "transparent"
    border.width: dragging ? 2 : 0
    z: dragging ? 10 : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 7 : 15
        anchors.rightMargin: root.compact ? 7 : 12
        spacing: root.compact ? 0 : 14

        Item { visible: root.compact; Layout.fillWidth: true }
        Rectangle {
            visible: root.running
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: Theme.success
        }
        MaterialIcon {
            icon: root.iconName
            iconSize: 25
            color: root.selected ? Theme.primary : root.foregroundColor
            Layout.preferredWidth: 30
        }
        Text {
            visible: !root.compact
            text: root.title
            color: root.selected ? Theme.primary : root.foregroundColor
            font.pixelSize: Theme.fontComponentTitle
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Item { visible: root.compact; Layout.fillWidth: true }

    }

    ToolTip.visible: root.compact && mouseArea.containsMouse
    ToolTip.text: root.title
    ToolTip.delay: 450

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property bool suppressClick: false
        drag.target: root.dragging ? root.dragTarget : null
        drag.axis: Drag.YAxis
        drag.minimumY: root.dragMinimumY
        drag.maximumY: root.dragMaximumY
        onPressAndHold: {
            if (root.draggable && root.dragTarget) {
                suppressClick = true
                root.dragging = true
            }
        }
        onReleased: {
            if (root.dragging && root.dragTarget)
                root.dragFinished(root.dragTarget.y + root.dragTarget.height / 2)
            root.dragging = false
        }
        onClicked: {
            if (!suppressClick)
                root.clicked()
            suppressClick = false
        }
        onCanceled: {
            root.dragging = false
            suppressClick = false
        }
    }
}
