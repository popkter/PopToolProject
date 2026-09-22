import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root
    required property var controller
    required property var parentWindow
    width: Math.min(Theme.dialogWidth, parentWindow.width - 24)
    height: Math.min(body.implicitHeight + topPadding + bottomPadding, parentWindow.height - 24)
    leftPadding: Theme.space16; rightPadding: Theme.space16
    closePolicy: Popup.CloseOnEscape
    contentItem: ColumnLayout {
        id: body
        spacing: Theme.space16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { text: "删除脚本？"; color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true
                text: "“" + (root.controller.selectedTool.title || "当前脚本") + "”将从本地删除，删除前会自动备份。"
                color: Theme.textSecondary; font.pixelSize: Theme.fontDialogDescription; wrapMode: Text.Wrap
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: Theme.space16
            PrimaryButton {
                Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium
                text: "删除"; iconName: ""; color: Theme.dangerAction; border.color: Theme.errorColor; foregroundColor: Theme.textPrimary
                onClicked: { if (root.controller.deleteSelected()) root.close() }
            }
            PrimaryButton {
                Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium
                text: "取消"; iconName: ""; onClicked: root.close()
            }
        }
    }
}
