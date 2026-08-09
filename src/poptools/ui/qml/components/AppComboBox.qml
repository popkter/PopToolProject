import QtQuick
import QtQuick.Controls
import "../theme"

ComboBox {
    id: control

    implicitHeight: 46
    leftPadding: 14
    rightPadding: 42
    font.pixelSize: 14

    contentItem: Text {
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        text: control.displayText
        color: control.enabled ? Theme.textPrimary : Theme.textSecondary
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: MaterialIcon {
        x: control.width - width - 14
        y: (control.height - height) / 2
        icon: control.popup.visible ? "expand_less" : "expand_more"
        iconSize: 20
        color: control.enabled ? Theme.textSecondary : Theme.outline
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: Theme.surface
        border.color: control.popup.visible || control.activeFocus
                      ? Theme.primary : Theme.outline
        border.width: control.popup.visible || control.activeFocus ? 2 : 1
    }

    delegate: ItemDelegate {
        width: control.popup.width - control.popup.leftPadding - control.popup.rightPadding
        height: 42
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            leftPadding: 12
            rightPadding: 12
            text: control.textAt(index)
            color: control.currentIndex === index
                   ? Theme.primaryText : Theme.textPrimary
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSmall
            color: control.currentIndex === index
                   ? Theme.primaryContainer
                   : (parent.highlighted ? Theme.surfaceContainerHigh : "transparent")
        }
    }

    popup: Popup {
        y: control.height + 6
        width: Math.max(control.width, 160)
        padding: 6
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 280)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: AppPopupSurface { }
    }
}
