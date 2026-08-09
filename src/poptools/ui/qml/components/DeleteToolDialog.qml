import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root

    required property var controller
    required property var parentWindow
    property string incomingTitle: ""
    property string existingTitle: ""
    property string errorMessage: ""
    signal scriptReplaced(string title)

    width: Math.min(368, parentWindow.width - 24)
    height: Math.min(236, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape

    onClosed: root.controller.cancelScriptImportReplacement()

    contentItem: ColumnLayout {
        spacing: Theme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            MaterialIcon {
                icon: "delete"
                iconSize: 24
                color: Theme.errorColor
            }
            Text {
                Layout.fillWidth: true
                text: "删除客制命令？"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontDialogTitle
                font.weight: Font.Bold
            }
        }
        Text {
            Layout.fillWidth: true
            text: "“" + (root.controller.selectedTool.title || "当前命令")
                  + "”将从本地脚本中删除。删除前会自动创建备份。"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            PrimaryButton {
                Layout.fillWidth: true
                implicitHeight: 44
                text: "取消"
                iconName: "close"
                tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                Layout.fillWidth: true
                implicitHeight: 44
                text: "删除"
                iconName: "delete"
                onClicked: {
                    if (root.controller.deleteSelected()) root.close()
                }
            }
        }
    }
}
