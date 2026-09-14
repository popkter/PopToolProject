import QtQuick
import QtQuick.Controls

Menu {
    id: control
    width: 208
    padding: 4
    overlap: 0
    popupType: Popup.Item
    font.pixelSize: 13
    delegate: AppMenuItem {}
    background: PopupSurface {}
}
