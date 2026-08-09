import QtQuick
import "../theme"

Item {
    id: root

    property color fillColor: Theme.surfaceContainer
    property color outlineColor: Theme.outlineVariant
    property int cornerRadius: Theme.radiusLarge

    Rectangle {
        x: -4
        y: -4
        width: parent.width + 8
        height: parent.height + 8
        radius: root.cornerRadius + 4
        color: Theme.darkMode ? "#52000000" : "#24000000"
    }
    Rectangle {
        x: -2
        y: -2
        width: parent.width + 4
        height: parent.height + 4
        radius: root.cornerRadius + 2
        color: Theme.darkMode ? "#66000000" : "#18000000"
    }
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.fillColor
        border.color: root.outlineColor
        border.width: 1
    }
}
