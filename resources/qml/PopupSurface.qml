import QtQuick
import QtQuick.Effects

Rectangle {
    radius: Theme.popupRadius
    color: Theme.surface
    border.color: Theme.border
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.16
        shadowBlur: 0.3
        shadowVerticalOffset: 2
    }
}
