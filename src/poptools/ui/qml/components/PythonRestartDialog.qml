import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    required property var parentWindow
    width: Math.min(500, parentWindow.width - 24)
    height: Math.min(220, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }
    contentItem: ColumnLayout {
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: Theme.radiusLarge
            color: Theme.surfaceContainerLow
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: Theme.radiusLarge; color: parent.color
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    radius: 12; color: Theme.primaryContainer
                    MaterialIcon { anchors.centerIn: parent; icon: "restart_alt"; iconSize: 24; color: Theme.primary }
                }
                Text {
                    Layout.fillWidth: true; text: "重启应用"
                    color: Theme.textPrimary; font.pixelSize: 20; font.weight: Font.Bold
                }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                anchors.topMargin: 18; anchors.bottomMargin: 14; spacing: 14
                Text {
                    Layout.fillWidth: true
                    text: "Python 环境已修改。应用将重启，以确保 Python Doctor 和脚本执行使用新的环境。"
                    color: Theme.textPrimary; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }
                PrimaryButton {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 126; implicitHeight: 48
                    text: "立即重启"; iconName: "restart_alt"
                    onClicked: root.controller.restartApplication()
                }
            }
        }
    }
}
