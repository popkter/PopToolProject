import QtQuick
import QtQuick.Controls
CheckBox {
    id: control
    implicitHeight: 32
    spacing: 8
    padding: 4
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.45
    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height-height)/2
        implicitWidth: 18; implicitHeight: 18
        radius: 4
        color: control.checked ? Theme.accent : control.hovered ? Theme.field : Theme.surface
        border.color: control.checked || control.activeFocus ? Theme.accent : Theme.border
        border.width: control.activeFocus ? 2 : 1
        Icon { anchors.centerIn: parent; name: "check"; font.pixelSize: 15; color: "white"; visible: control.checked }
    }
    contentItem: Text {
        text: control.text; font: control.font; color: Theme.text
        leftPadding: control.indicator.width+control.spacing
        verticalAlignment: Text.AlignVCenter
    }
}
