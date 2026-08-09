import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var parentWindow
    property string message: ""
    width: Math.min(500, parentWindow.width - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    title: "Python Doctor"
    standardButtons: Dialog.Ok
    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
    }
    contentItem: RowLayout {
        spacing: 14
        MaterialIcon { icon: "medical_services"; iconSize: 28; color: Theme.primary }
        Text {
            Layout.fillWidth: true
            text: root.message
            color: Theme.textPrimary
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }
}
