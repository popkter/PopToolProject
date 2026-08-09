import QtQuick
import QtQuick.Effects
import "../theme"

Item {
    id: root

    property color fillColor: Theme.popupSurface
    property color outlineColor: Theme.outlineVariant
    property int cornerRadius: Theme.radiusMedium
    property bool dialogSurface: false

    MultiEffect {
        anchors.fill: surface
        source: surface
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: root.dialogSurface ? Theme.dialogShadow : Theme.popupShadow
        shadowBlur: root.dialogSurface ? 0.9 : 0.65
        shadowVerticalOffset: root.dialogSurface ? 18 : 10
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.fillColor
        border.color: root.outlineColor
        border.width: 1
    }
}
