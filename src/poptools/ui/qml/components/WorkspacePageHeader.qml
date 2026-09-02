import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    required property string title
    required property string description
    property bool compact: false
    property real actionWidth: 0
    default property alias actions: actionRow.children

    implicitHeight: compact ? 54 : 68

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Theme.space4

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.pixelSize: root.compact ? Theme.fontTitleLarge : Theme.fontPageTitle
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                visible: !root.compact && root.description.length > 0
                text: root.description
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: root.actionWidth
            Layout.minimumWidth: root.actionWidth
            spacing: Theme.controlSpacing
        }
    }
}
