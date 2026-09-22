import QtQuick
import QtQuick.Controls
import "../theme"

Menu {
    id: control

    implicitWidth: Theme.menuWidth
    padding: Theme.space8
    overlap: 0

    background: AppPopupSurface {
        cornerRadius: Theme.radiusMedium
    }
}
