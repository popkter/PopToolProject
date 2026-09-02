import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root

    required property var controller
    required property var parentWindow
    property bool replacementMode: false
    property string incomingTitle: ""
    property string existingTitle: ""
    property string errorMessage: ""
    signal scriptReplaced(string title)

    width: Math.min(540, parentWindow.width - 24)
    height: Math.min(320, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

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
        spacing: 14

        MaterialIcon {
            icon: root.replacementMode ? "content_copy" : "error"
            iconSize: 36
            color: root.replacementMode ? Theme.primary : Theme.errorColor
        }
        Text {
            text: root.replacementMode ? "发现相同 ID 的脚本" : "无法导入脚本"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontDialogTitle
            font.weight: Font.Bold
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
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                implicitWidth: 110
                implicitHeight: 48
                text: root.replacementMode ? "取消" : "关闭"
                iconName: ""
                tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                visible: root.replacementMode
                implicitWidth: 130
                implicitHeight: 48
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
