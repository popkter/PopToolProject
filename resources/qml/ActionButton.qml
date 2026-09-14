import QtQuick
import QtQuick.Controls
Button {
    id: control
    property bool primary: false
    property bool danger: false
    property bool selected: false
    implicitHeight: 38
    leftPadding: 18
    rightPadding: 18
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.45
    contentItem: Text { text: control.text; font: control.font; color: control.primary ? "white" : control.selected ? Theme.accent : control.danger ? "#e05252" : Theme.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    background: Rectangle { radius: 7; color: control.primary ? Theme.accent : control.selected ? Theme.selected : control.hovered ? Theme.field : Theme.surface; border.color: control.primary || control.selected ? Theme.accent : Theme.border; opacity: control.down ? 0.75 : 1 }
}
