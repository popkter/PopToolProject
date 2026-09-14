import QtQuick
Text {
    property string name: "terminal"
    text: name
    font.family: "Material Icons Round"
    font.pixelSize: 22
    color: Theme.muted
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
