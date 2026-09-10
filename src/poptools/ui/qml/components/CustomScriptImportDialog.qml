import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root

    required property var controller
    required property var parentWindow
    property bool replacementMode: false
    property string incomingTitle: ""
    property string existingTitle: ""
    property string errorMessage: ""
    signal scriptReplaced(string title)

    width: Math.min(368, parentWindow.width - 24)
    height: Math.min(root.replacementMode ? 236 : 216, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    function openForReplacement(result) {
        replacementMode = true
        incomingTitle = result.title || "导入的脚本"
        existingTitle = result.existingTitle || "现有脚本"
        errorMessage = ""
        open()
    }

    function openForError(message) {
        replacementMode = false
        incomingTitle = ""
        existingTitle = ""
        errorMessage = message
        open()
    }

    onClosed: root.controller.cancelScriptImportReplacement()

    contentItem: ColumnLayout {
        spacing: Theme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            MaterialIcon {
                icon: root.replacementMode ? "content_copy" : "error"
                iconSize: 24
                color: root.replacementMode ? Theme.primary : Theme.errorColor
            }
            Text {
                Layout.fillWidth: true
                text: root.replacementMode ? "发现相同 ID 的脚本" : "无法导入脚本"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontDialogTitle
                font.weight: Font.Bold
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.replacementMode
                  ? "导入的“" + root.incomingTitle + "”与现有脚本“"
                    + root.existingTitle + "”使用相同 ID。是否替换现有脚本？"
                  : root.errorMessage
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
                text: root.replacementMode ? "取消" : "关闭"
                iconName: "close"
                tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                Layout.fillWidth: true
                visible: root.replacementMode
                implicitHeight: 44
                text: "确认替换"
                iconName: "sync"
                onClicked: {
                    var result = root.controller.confirmScriptImportReplacement()
                    if (result.status === "error") {
                        root.openForError(result.message || "替换脚本失败")
                        return
                    }
                    root.scriptReplaced(result.title)
                    root.close()
                }
            }
        }
    }
}
