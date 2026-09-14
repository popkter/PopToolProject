import QtQuick
import QtQuick.Layouts
Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    default property alias body: content.data
    implicitHeight: content.implicitHeight + 80
    radius: 9
    color: Theme.surface
    border.color: Theme.border
    RowLayout {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
        spacing: 10
        Icon { name: card.icon; color: Theme.accent; visible: card.icon !== ""; Layout.alignment: Qt.AlignTop }
        ColumnLayout { spacing: 2; Layout.fillWidth: true
            Text { text: card.title; color: Theme.text; font.pixelSize: 16; font.bold: true }
            Text { text: card.subtitle; color: Theme.muted; font.pixelSize: 11; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
        }
    }
    ColumnLayout { id: content; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16; anchors.topMargin: 64; spacing: 12 }
}
