import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root
    required property var backend
    spacing: Theme.space12
    Repeater {
        model: root.backend ? root.backend.plugins : []
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space8
            Text {
                Layout.fillWidth: true
                text: modelData.name + (modelData.version ? "  " + modelData.version : "")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                font.bold: true
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: modelData.status + (modelData.latest ? " · 最新 " + modelData.latest : "")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
                wrapMode: Text.Wrap
            }
            AppProgressBar {
                Layout.fillWidth: true
                visible: modelData.busy
                value: modelData.progress / 100
                indeterminate: modelData.progress === 0
            }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.space8
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 68; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: !modelData.installed; enabled: !modelData.busy
                    text: "安装"
                    onClicked: root.backend.operate(modelData.id, "install")
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 88; iconName: ""; labelFontSize: Theme.fontCaption
                    enabled: !modelData.busy; tonal: true
                    text: "检查更新"
                    onClicked: root.backend.operate(modelData.id, "check")
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 68; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: modelData.installed && modelData.canUpdate; enabled: !modelData.busy
                    text: "更新"
                    onClicked: root.backend.operate(modelData.id, "update")
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 68; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: modelData.recorded; enabled: !modelData.busy; tonal: true
                    text: "修复"
                    onClicked: root.backend.operate(modelData.id, "repair")
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 68; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: modelData.recorded; enabled: !modelData.busy; tonal: true
                    text: "卸载"
                    onClicked: { confirm.pluginId = modelData.id; confirm.pluginName = modelData.name; confirm.open() }
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 68; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: modelData.busy; tonal: true
                    text: "取消"
                    onClicked: root.backend.cancel(modelData.id)
                }
                PrimaryButton {
                    height: Theme.controlHeightSmall; implicitWidth: 112; iconName: ""; labelFontSize: Theme.fontCaption
                    visible: modelData.id === "android" && modelData.installed
                    enabled: !modelData.busy; tonal: true
                    text: "停止设备服务"
                    onClicked: root.backend.operate(modelData.id, "stop-server")
                }
            }
        }
    }
    AppDialog {
        id: confirm
        objectName: "pluginUninstallDialog"
        property string pluginId: ""
        property string pluginName: ""
        parent: Overlay.overlay
        width: Math.min(Theme.dialogWidth, parent.width - Theme.space24)
        leftPadding: Theme.space16; rightPadding: Theme.space16
        closePolicy: Popup.CloseOnEscape
        contentItem: ColumnLayout {
            spacing: Theme.space16
            Text {
                Layout.fillWidth: true
                text: "卸载 " + confirm.pluginName + "？"
                color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle
                font.weight: Font.DemiBold; wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: "卸载后相关功能将不可用。" + (confirm.pluginId === "python" ? "Python 环境及已安装依赖也会删除。" : "") + "用户脚本、配置和输出文件会保留。"
                color: Theme.textSecondary; font.pixelSize: Theme.fontDialogDescription
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.space16
                PrimaryButton {
                    objectName: "confirmPluginUninstall"
                    Layout.fillWidth: true; Layout.preferredWidth: 0
                    implicitHeight: Theme.controlHeightLarge
                    text: "卸载"; iconName: "delete_outline"
                    color: Theme.dangerAction; border.color: Theme.errorColor
                    foregroundColor: Theme.textPrimary
                    onClicked: confirm.accept()
                }
                PrimaryButton {
                    Layout.fillWidth: true; Layout.preferredWidth: 0
                    implicitHeight: Theme.controlHeightLarge
                    text: "取消"; iconName: ""; onClicked: confirm.reject()
                }
            }
        }
        onAccepted: root.backend.operate(pluginId, "uninstall")
    }
}
