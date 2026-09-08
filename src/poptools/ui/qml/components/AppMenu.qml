import QtQuick
import QtQuick.Controls
import "../theme"

Menu {
    id: control

    implicitWidth: 270
    padding: Theme.space8
    overlap: 0

    background: AppPopupSurface {
        cornerRadius: Theme.radiusMedium
    }
}
