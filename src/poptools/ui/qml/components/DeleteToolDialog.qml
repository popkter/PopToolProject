import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    required property var parentWindow
    width: Math.min(520, parentWindow.width - 24)
    height: Math.min(300, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    background: Rectangle { radius: Theme.radiusLarge; color: Theme.surface }

    contentItem: ColumnLayout {
        spacing: 14
        MaterialIcon { icon: "delete"; iconSize: 34; color: Theme.errorColor }
        Text {
            text: "删除客制命令？"
            color: Theme.textPrimary
            font.pixelSize: 23
            font.weight: Font.Bold
        }
        Text {
            Layout.fillWidth: true
            text: "“" + (root.controller.selectedTool.title || "当前命令")
                  + "”将从本地脚本中删除。删除前会自动创建备份。"
            color: Theme.textSecondary
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                implicitWidth: 110; implicitHeight: 48
                text: "取消"; iconName: ""; tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                implicitWidth: 120; implicitHeight: 48
                text: "删除"; iconName: "delete"
                onClicked: if (root.controller.deleteSelected()) root.close()
            }
        }
    }
}
