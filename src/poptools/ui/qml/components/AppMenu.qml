import QtQuick
import QtQuick.Controls
import "../theme"

Menu {
    id: control

    implicitWidth: 180
    padding: Theme.space8
    overlap: 0

    background: AppPopupSurface {
        cornerRadius: Theme.radiusMedium
    }
}
