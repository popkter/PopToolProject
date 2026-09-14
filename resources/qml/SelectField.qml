import QtQuick
import QtQuick.Controls
ComboBox {
    id: control
    implicitHeight: 38
    leftPadding: 12
    rightPadding: 34
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.45
    delegate: ItemDelegate {
        width: control.popup.availableWidth
        implicitHeight: 32
        leftPadding: 12; rightPadding: 12
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.textAt(index); textFormat: Text.PlainText; font: control.font
            color: parent.highlighted ? "white" : Theme.text
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        background: Rectangle { radius: 4; color: parent.highlighted ? Theme.accent : "transparent" }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
        margins: 8
        popupType: Popup.Item
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: PopupSurface {}
    }
    contentItem: Text {
        text: control.displayText; font: control.font; color: Theme.text
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width-width-10; y: (control.height-height)/2
        name: "expand_more"; color: Theme.muted; font.pixelSize: 18
    }
    background: Rectangle {
        radius: 6; color: control.hovered ? Theme.field : Theme.surface
        border.color: control.activeFocus || control.down ? Theme.accent : Theme.border
    }
}
