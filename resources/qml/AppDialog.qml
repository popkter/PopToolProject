import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: control
    property string acceptText: "确定"
    property string rejectText: "取消"
    property bool destructive: false
    readonly property bool hasAccept: (standardButtons & (Dialog.Ok | Dialog.Yes | Dialog.Save)) !== 0
    readonly property bool hasReject: (standardButtons & (Dialog.Cancel | Dialog.No)) !== 0
    width: Math.min(480, parent ? parent.width - 48 : 480)
    padding: 20
    topPadding: 8
    font.pixelSize: 13
    palette.windowText: Theme.text
    palette.text: Theme.text
    palette.buttonText: Theme.text
    palette.base: Theme.surface
    palette.highlight: Theme.accent
    palette.highlightedText: "white"
    popupType: Popup.Item
    background: PopupSurface { radius: Theme.dialogRadius }
    Overlay.modal: Rectangle { color: "#660b1220" }
    header: Label {
        text: control.title; textFormat: Text.PlainText
        color: Theme.text; font.pixelSize: 20; font.bold: true
        padding: 20; bottomPadding: 8; wrapMode: Text.Wrap
        visible: text.length > 0
    }
    footer: Item {
        visible: control.standardButtons !== Dialog.NoButton
        implicitHeight: visible ? 58 : 0
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.bottomMargin: 20
            spacing: 12
            ActionButton {
                Layout.fillWidth: true
                visible: control.hasReject
                text: control.destructive ? control.acceptText : control.rejectText
                danger: control.destructive
                onClicked: control.destructive ? control.accept() : control.reject()
            }
            ActionButton {
                Layout.fillWidth: true
                primary: true
                text: control.hasAccept ? (control.destructive && control.hasReject ? control.rejectText : control.acceptText) : "关闭"
                onClicked: control.hasAccept && !(control.destructive && control.hasReject) ? control.accept() : control.reject()
            }
        }
    }
}
