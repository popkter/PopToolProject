import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root
    required property var controller
    signal copyRequested(string text)
    property var parameterValues: ({})
    property var preview: ({parameters: [], result: "", error: ""})
    property var parameters: []
    spacing: Theme.space12
    function parseTemplate() {
        if (!controller) return
        parameterValues = ({})
        preview = controller.previewGuideTemplate(editor.text, parameterValues)
        parameters = preview.parameters
    }
    function setValue(key, value) {
        parameterValues[key] = value
        preview = controller.previewGuideTemplate(editor.text, parameterValues)
    }
    Text { text: "试一试 · 参数如何变成命令"; color: Theme.textPrimary; font.pixelSize: Theme.fontTitleSmall; font.weight: Font.DemiBold }
    Text {
        Layout.fillWidth: true; text: "输入模板后自动生成参数，只预览替换结果，不执行命令。支持 @file、@dir、Var 和旧版 pVal 声明。"
        color: Theme.textSecondary; font.pixelSize: Theme.fontBody; wrapMode: Text.Wrap
    }
    TextArea {
        id: editor
        objectName: "guideTemplateEditor"
        Layout.fillWidth: true
        text: "adb shell settings put system show_touches ${触摸点显示:开启=1|关闭=0}"
        wrapMode: TextEdit.Wrap; selectByMouse: true; textFormat: TextEdit.PlainText
        font.family: "Cascadia Mono"; font.pixelSize: Theme.fontCode
        color: Theme.textPrimary; padding: Theme.space12
        background: Rectangle { radius: Theme.radiusControl; color: Theme.inputDefault; border.color: editor.activeFocus ? Theme.primary : Theme.outline }
        onTextChanged: root.parseTemplate()
    }
    Repeater {
        model: root.parameters
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: Theme.space4
            Text { text: modelData.label; color: Theme.textPrimary; font.pixelSize: Theme.fontSupporting }
            RowLayout {
                Layout.fillWidth: true
                AppTextField {
                    id: field
                    Layout.fillWidth: true; visible: modelData.kind !== "choice"
                    text: modelData.default || ""; color: Theme.textPrimary; selectByMouse: true
                    font.pixelSize: Theme.fontBody
                    background: Rectangle { radius: Theme.radiusControl; color: Theme.inputDefault; border.color: Theme.outline }
                    onTextEdited: root.setValue(modelData.id, text)
                }
                AppComboBox {
                    Layout.fillWidth: true; visible: modelData.kind === "choice"
                    model: modelData.options; textRole: "label"; valueRole: "value"
                    onActivated: root.setValue(modelData.id, currentValue)
                }
                PrimaryButton {
                    visible: modelData.kind === "file" || modelData.kind === "directory"
                    text: "选择"; iconName: "folder_open"; tonal: true
                    onClicked: {
                        const path = root.controller.chooseGuidePath(modelData.kind)
                        if (path) { field.text = path; root.setValue(modelData.id, path) }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true; visible: !!root.preview.error; text: root.preview.error
        color: Theme.errorColor; font.pixelSize: Theme.fontBody; wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "替换结果"; color: Theme.textPrimary; font.pixelSize: Theme.fontSupporting }
        PrimaryButton {
            text: "复制结果"; iconName: "content_copy"; tonal: true
            enabled: !root.preview.error && !!root.preview.result
            onClicked: root.copyRequested(root.preview.result)
        }
    }
    TextArea {
        objectName: "guideTemplateResult"
        Layout.fillWidth: true; text: root.preview.result
        readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText; color: Theme.consoleText
        font.family: "Cascadia Mono"; font.pixelSize: Theme.fontCode; padding: Theme.space12
        background: Rectangle { radius: Theme.radiusConsole; color: Theme.consoleBackground }
    }
    Component.onCompleted: parseTemplate()
}
