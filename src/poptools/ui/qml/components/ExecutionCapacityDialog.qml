import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root

    required property var controller
    property string victimTitle: ""
    property string requestedTitle: ""

    width: Math.min(560, parent ? parent.width - 24 : 560)
    height: Math.min(310, parent ? parent.height - 24 : 310)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.NoAutoClose
    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
    }

    Connections {
        target: root.controller
        function onExecutionCapacityRequested(victimTitle, requestedTitle) {
            root.victimTitle = victimTitle
            root.requestedTitle = requestedTitle
            root.open()
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        MaterialIcon {
            icon: "swap_horiz"
            iconSize: 36
            color: Theme.primary
        }
        Text {
            text: "运行名额已用完"
            font.pixelSize: Theme.fontDialogTitle
            font.weight: Font.Bold
            color: Theme.textPrimary
        }
        Text {
            Layout.fillWidth: true
            text: "是否停止最先运行的“" + root.victimTitle
                  + "”，并开始“" + root.requestedTitle + "”？"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                implicitWidth: 110
                implicitHeight: 48
                text: "取消"
                iconName: ""
                tonal: true
                onClicked: {
                    root.controller.cancelExecutionReplacement()
                    root.close()
                }
            }
            PrimaryButton {
                implicitWidth: 150
                implicitHeight: 48
                text: "停止并运行"
                iconName: "play_arrow"
                onClicked: {
                    root.controller.confirmExecutionReplacement()
                    root.close()
                }
            }
        }
    }
}
