import QtQuick
import QtQuick.Controls
TextField {
    id: control
    implicitHeight: 38
    leftPadding: 11; rightPadding: 11
    color: Theme.text
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    font.pixelSize: 13
    background: Rectangle { radius: 6; color: Theme.surface; border.color: control.activeFocus ? Theme.accent : Theme.border }
}
