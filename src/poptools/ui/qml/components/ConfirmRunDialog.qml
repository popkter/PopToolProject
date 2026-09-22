import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root
    required property var controller
    required property var parentWindow
    property var pendingValues: ({})
    width: Math.min(Theme.dialogWidth, parentWindow.width - 24)
    height: Math.min(body.implicitHeight + topPadding + bottomPadding, parentWindow.height - 24)
    leftPadding: Theme.space16; rightPadding: Theme.space16
    closePolicy: Popup.CloseOnEscape
    function openForRun(values) { pendingValues = Object.assign({}, values); open() }
    contentItem: ColumnLayout {
        id: body
        spacing: Theme.space16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { Layout.fillWidth: true; text: "运行“" + (root.controller.selectedTool.title || "当前脚本") + "”？"; color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; text: "运行前请确认目标设备与输入参数。"; color: Theme.textSecondary; font.pixelSize: Theme.fontDialogDescription; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: Theme.space16
            PrimaryButton { Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium; text: "取消"; iconName: ""; tonal: true; color: Theme.surfaceContainerLow; border.color: Theme.outline; foregroundColor: Theme.textPrimary; onClicked: root.close() }
            PrimaryButton {
                Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium
                text: "继续运行"; iconName: ""
                onClicked: { root.close(); root.controller.runSelected(root.pendingValues) }
            }
        }
    }
}
