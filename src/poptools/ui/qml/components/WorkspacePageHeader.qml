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

    implicitHeight: compact ? Theme.pageHeaderCompactHeight : Theme.pageHeaderHeight

    Item {
        anchors.fill: parent

        Column {
            anchors.top: parent.top
            width: Math.max(0, parent.width - root.actionWidth - Theme.space12)
            spacing: Theme.space4
            Text {
                width: parent.width
                text: root.title
                color: Theme.textPrimary
                font.pixelSize: root.titlePixelSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                visible: !root.compact && root.description.length > 0
                text: root.description
                color: Theme.textSecondary
                font.pixelSize: Theme.fontPageDescription
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        RowLayout {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.actionWidth
            spacing: Theme.space16
        }
    }
}
