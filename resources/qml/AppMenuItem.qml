import QtQuick
import QtQuick.Controls

MenuItem {
    id: control
    property string shortcutHint: ""
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 12
    font.pixelSize: 13
    contentItem: Item {
        implicitWidth: caption.implicitWidth + hint.implicitWidth + (hint.text ? 28 : 0)
        implicitHeight: 20
        Text {
            id: caption; anchors.left: parent.left; anchors.right: hint.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            text: control.text; textFormat: Text.PlainText; font: control.font; elide: Text.ElideRight
            color: !control.enabled ? Theme.muted : control.highlighted ? "white" : Theme.text
        }
        Text {
            id: hint; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: control.shortcutHint; font.pixelSize: 11
            color: control.highlighted && control.enabled ? "white" : Theme.muted
        }
    }
    background: Rectangle { radius: 4; color: control.highlighted && control.enabled ? Theme.accent : "transparent" }
}
