import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    clip: true
    required property string label
    required property string iconName
    property bool selected: false
    property bool compact: false
    property bool dense: false
    signal clicked()

    implicitHeight: dense ? 58 : 66
    radius: Theme.radiusLarge
    color: selected ? Theme.primaryContainer : (mouseArea.containsMouse ? Theme.surfaceContainer : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 8 : 20
        anchors.rightMargin: root.compact ? 8 : 14
        spacing: root.compact ? 0 : 16

        Item { visible: root.compact; Layout.fillWidth: true }
        MaterialIcon {
            icon: root.iconName
            iconSize: 27
            color: root.selected ? Theme.primary : Theme.textPrimary
            Layout.preferredWidth: 32
        }
        Text {
            visible: !root.compact
            text: root.label
            color: root.selected ? Theme.primary : Theme.textPrimary
            font.pixelSize: 17
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
        }
        Item { visible: root.compact; Layout.fillWidth: true }
    }

    ToolTip.visible: root.compact && mouseArea.containsMouse
    ToolTip.text: root.label
    ToolTip.delay: 450

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
