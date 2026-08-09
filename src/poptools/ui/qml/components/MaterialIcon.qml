import QtQuick
import "../theme"

Text {
    id: root
    property string icon: "circle"
    property int iconSize: 24
    text: icon
    color: Theme.textPrimary
    font.family: "Material Icons Round"
    font.pixelSize: iconSize
    font.weight: Font.Normal
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}


