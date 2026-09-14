import QtQuick
import QtQuick.Controls

ToolButton {
    id: control
    property string iconName: "add"
    implicitWidth: 32
    implicitHeight: 32
    padding: 6
    opacity: enabled ? 1 : 0.45
    contentItem: Icon {
        name: control.iconName
        font.pixelSize: 20
        color: control.down || control.hovered || control.activeFocus ? Theme.accent : Theme.muted
    }
    background: Rectangle {
        radius: 7
        color: control.down ? Theme.selected : control.hovered ? Theme.field : "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
}
