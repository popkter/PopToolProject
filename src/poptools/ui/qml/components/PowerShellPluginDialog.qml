import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root
    required property var controller
    required property var parentWindow
    property bool cancelRequested: false
    width: Math.min(Theme.dialogWidth, Overlay.overlay.width - 24)
    height: Math.min(Math.max(321, body.implicitHeight + 48), Overlay.overlay.height - 24)
    leftPadding: Theme.space16
    rightPadding: Theme.space16
    closePolicy: controller.pluginInstalling ? Popup.NoAutoClose : Popup.CloseOnEscape

    function cancel() {
        if (!controller.pluginInstalling) { close(); return }
        if (!cancelRequested && controller.cancelPowerShellPluginInstall())
            cancelRequested = true
    }
    onOpened: cancelRequested = false
    onClosed: cancelRequested = false
    Connections {
        target: root.controller
        function onPluginInstallFinished(success, message) {
            if (root.cancelRequested) { root.cancelRequested = false; root.close() }
        }
    }
    contentItem: ColumnLayout {
        id: body
        spacing: Theme.space16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: root.controller.pluginInstalled ? "PowerShell 7" : "安装 PowerShell 7"; color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: "安装后可运行对应脚本"; color: Theme.textSecondary; font.pixelSize: Theme.fontDialogDescription; wrapMode: Text.Wrap }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: Theme.controlHeightLarge
            radius: Theme.radiusMedium; color: Theme.surfaceContainer; border.color: Theme.outline
            Text { anchors.left: parent.left; anchors.leftMargin: Theme.space16; anchors.verticalCenter: parent.verticalCenter; text: root.controller.pluginVersion; color: Theme.textPrimary; font.pixelSize: Theme.fontPageDescription }
        }
        Text {
            Layout.fillWidth: true
            text: root.controller.pluginInstallStatus || (root.controller.pluginInstalled ? "已安装" : "将下载应用专用的官方运行环境")
            font.pixelSize: Theme.fontDialogDescription
            color: text.indexOf("失败") >= 0 ? Theme.errorColor : Theme.textSecondary
            wrapMode: Text.Wrap
        }
        AppProgressBar {
            id: progressBar
            Layout.fillWidth: true; Layout.preferredHeight: 24
            visible: root.controller.pluginInstalling
            from: 0; to: 100; value: root.controller.pluginInstallProgress
            
            
        }
        Text {
            Layout.fillWidth: true
            text: root.controller.pluginDirectory
            color: Theme.textSecondary; font.pixelSize: Theme.fontCaption
            elide: Text.ElideMiddle
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true; spacing: Theme.space16
            PrimaryButton {
                Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium
                text: root.controller.pluginInstalling ? "取消安装" : "关闭"; iconName: ""; tonal: true
                color: Theme.surfaceContainerLow; border.color: Theme.outline; foregroundColor: Theme.textPrimary
                enabled: !root.cancelRequested; onClicked: root.cancel()
            }
            PrimaryButton {
                Layout.fillWidth: true; Layout.preferredWidth: 0; implicitHeight: Theme.controlHeightLarge; radius: Theme.radiusMedium
                text: root.controller.pluginInstalling ? "安装中…" : root.controller.pluginInstalled ? "已安装" : "安装使用"; iconName: ""
                enabled: !root.controller.pluginInstalling && !root.controller.pluginInstalled
                onClicked: root.controller.installPowerShellPlugin()
            }
        }
    }
}
