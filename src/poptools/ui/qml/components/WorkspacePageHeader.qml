import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    required property string title
    required property string description
    property bool compact: false
    property real actionWidth: 0
    property int titlePixelSize: compact ? Theme.fontTitleLarge : Theme.fontPageTitle
    default property alias actions: actionRow.children

    implicitHeight: compact ? 54 : 68

    Item {
        anchors.fill: parent

        // Match the preset page's title and subtitle baselines.
        Text {
            x: 0
            y: 1
            width: Math.max(0, parent.width - root.actionWidth - Theme.space12)
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: root.titlePixelSize
            font.weight: Font.Bold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            x: 0
            y: 47
            width: Math.max(0, parent.width - root.actionWidth - Theme.space12)
            visible: !root.compact && root.description.length > 0
            text: root.description
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        RowLayout {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.actionWidth
            spacing: Theme.controlSpacing
        }
    }
}
