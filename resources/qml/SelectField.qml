import QtQuick
import QtQuick.Controls
ComboBox {
    id: control
    implicitHeight: 38
    leftPadding: 12
    rightPadding: 34
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: control.displayText; font: control.font; color: Theme.text
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width-width-10; y: (control.height-height)/2
        name: "expand_more"; color: Theme.muted; font.pixelSize: 18
    }
    background: Rectangle {
        radius: 6; color: control.hovered ? Theme.field : Theme.surface
        border.color: control.activeFocus || control.down ? Theme.accent : Theme.border
    }
}
