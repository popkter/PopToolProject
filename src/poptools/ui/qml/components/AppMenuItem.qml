import QtQuick
import QtQuick.Controls
import "../theme"

MenuItem {
    id: control

    property bool destructive: false

    implicitHeight: 38
    leftPadding: Theme.space12
    rightPadding: Theme.space12

    contentItem: Text {
        text: control.text
        color: control.destructive ? Theme.errorColor
              : control.enabled ? Theme.textPrimary : Theme.textSecondary
        opacity: control.enabled ? 1 : 0.48
        font.pixelSize: Theme.fontSupporting
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.highlighted ? Theme.popupHover : "transparent"
    }
}
