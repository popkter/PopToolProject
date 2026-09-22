import QtQuick
import QtQuick.Controls
import "../theme"

TextField {
    id: control
    implicitHeight: Theme.controlHeight
    font.pixelSize: Theme.fontBody
    color: enabled ? Theme.textPrimary : Theme.textSecondary
    placeholderTextColor: Theme.textSecondary
    selectionColor: Theme.primaryContainer
    selectedTextColor: Theme.textPrimary
    selectByMouse: true
    leftPadding: Theme.space12; rightPadding: Theme.space12
    background: Rectangle {
        radius: Theme.radiusControl
        color: control.enabled ? Theme.inputDefault : Theme.inputDisabled
        border.color: control.activeFocus ? Theme.primary : Theme.outline
        border.width: control.activeFocus ? 2 : 1
    }
}
