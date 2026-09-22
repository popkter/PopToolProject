import QtQuick
import QtQuick.Controls
import "../theme"

ProgressBar {
    id: control
    property real phase: 0
    implicitHeight: Theme.space8
    background: Rectangle { radius: height / 2; color: Theme.surfaceContainerHigh }
    contentItem: Item {
        clip: true
        Rectangle {
            id: fill
            height: parent.height; radius: height / 2; color: Theme.primary
            width: parent.width * (control.indeterminate ? 0.3 : control.visualPosition)
            x: control.indeterminate ? -width + control.phase * (parent.width + width) : 0
        }
    }
    NumberAnimation on phase {
        running: control.indeterminate && control.visible
        loops: Animation.Infinite; from: 0; to: 1; duration: 1100
    }
}
