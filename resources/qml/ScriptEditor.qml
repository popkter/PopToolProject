import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UTerminal 1.0
AppDialog {
    id: editor
    property bool advancedExpanded: false
    readonly property string languageName: Scripts.draft.language === "python" ? "Python" : Scripts.draft.language === "cmd" ? "CMD / BAT" : "PowerShell 7"
    anchors.centerIn: parent; width: Math.min(900,parent.width-80); height: Math.min(830,parent.height-60); modal: true
    padding: 20
    title: (Scripts.draft.id ? "编辑脚本" : "新建脚本") + " · " + languageName
    AppDialog {
        id: iconDialog; objectName: "scriptIconDialog"
        title: "选择脚本图标"; modal: true; anchors.centerIn: parent
        width: Math.min(520,editor.width-32); height: Math.min(520,editor.height-32)
        standardButtons: Dialog.Close
        GridView {
            anchors.fill: parent; clip: true; cellWidth: width/4; cellHeight: 74
            ScrollBar.vertical: ScrollBar {}
            model: ListModel {
                ListElement { symbol: "terminal"; label: "终端" }
                ListElement { symbol: "code"; label: "代码" }
                ListElement { symbol: "folder"; label: "文件夹" }
                ListElement { symbol: "description"; label: "文档" }
                ListElement { symbol: "build"; label: "构建" }
                ListElement { symbol: "settings"; label: "设置" }
                ListElement { symbol: "storage"; label: "存储" }
                ListElement { symbol: "cloud"; label: "云端" }
                ListElement { symbol: "download"; label: "下载" }
                ListElement { symbol: "upload"; label: "上传" }
                ListElement { symbol: "sync"; label: "同步" }
                ListElement { symbol: "search"; label: "查找" }
                ListElement { symbol: "bug_report"; label: "调试" }
                ListElement { symbol: "computer"; label: "电脑" }
                ListElement { symbol: "language"; label: "网络" }
                ListElement { symbol: "lock"; label: "锁定" }
                ListElement { symbol: "timer"; label: "计时" }
                ListElement { symbol: "bolt"; label: "快捷操作" }
                ListElement { symbol: "image"; label: "图片" }
                ListElement { symbol: "star"; label: "收藏" }
            }
            delegate: ToolButton {
                required property string symbol
                required property string label
                width: GridView.view.cellWidth-4; height: GridView.view.cellHeight-4
                Accessible.name: label
                background: Rectangle { radius: 6; color: Scripts.draft.icon===symbol ? Theme.selected : parent.hovered ? Theme.field : "transparent"; border.color: Scripts.draft.icon===symbol ? Theme.accent : "transparent" }
                contentItem: ColumnLayout {
                    spacing: 4
                    Icon { name: symbol; color: Theme.accent; font.pixelSize: 28; Layout.alignment: Qt.AlignHCenter }
                    Label { text: label; color: Theme.text; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                }
                onClicked: { Scripts.updateDraft("icon",symbol);iconDialog.close() }
            }
        }
    }
    ColumnLayout { objectName: "scriptEditorBody"; anchors.fill: parent; spacing: 12
        RowLayout { Layout.fillWidth: true
            ToolButton {
                objectName: "scriptIconButton"
                contentItem: Icon { name: Scripts.draft.icon || "terminal"; color: Theme.accent; font.pixelSize: 28 }
                onClicked: iconDialog.open()
                Accessible.name: "选择脚本图标"
                ToolTip.visible: hovered; ToolTip.text: "选择脚本图标"
            }
            Field { Layout.fillWidth: true; placeholderText: "脚本名称"; text: Scripts.draft.title || ""; onTextEdited: Scripts.updateDraft("title",text) }
            SelectField { id: language; Layout.preferredWidth: 156; model: [{label:"PowerShell 7",value:"powershell"},{label:"Python",value:"python"},{label:"CMD / BAT",value:"cmd"}]; textRole: "label"; valueRole: "value"; currentIndex: Math.max(0,["powershell","python","cmd"].indexOf(Scripts.draft.language)); onActivated: { Scripts.updateDraft("language",currentValue); App.noteEditorInput() } }
        }
        Field { Layout.fillWidth: true; placeholderText: "描述"; text: Scripts.draft.description || ""; onTextEdited: Scripts.updateDraft("description",text) }
        RowLayout { Layout.fillWidth: true; visible: (Scripts.draft.language === "python" && !Plugins.pythonReady) || (Scripts.draft.language === "powershell" && !Plugins.powerShellReady)
            Label { text: "缺少运行插件，仍可编辑和保存。"; color: Theme.muted; Layout.fillWidth: true }
            ActionButton { text: "安装插件"; onClicked: App.showPlugin(Scripts.draft.language) }
        }
        Label { text: "参数示例：${名称:默认值}。参数按文本替换，请在源码中安排好引号与转义。"; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
        ScrollView { id: codeScroll; objectName: "scriptCodeViewport"; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 110; clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.active: true
            background: Rectangle { radius: 6; color: Theme.field; border.color: code.activeFocus ? Theme.accent : Theme.border }
            TextArea { id: code; objectName: "scriptCodeEditor"; text: Scripts.draft.code || ""; textFormat: TextEdit.PlainText; color: Theme.text; font.family: Settings.fontFamily; font.pixelSize: 14; padding: 12; background: null; selectByMouse: true; wrapMode: TextEdit.NoWrap; placeholderText: "输入脚本代码"; onTextChanged: { if(activeFocus && text !== Scripts.draft.code) { Scripts.updateDraft("code",text); App.noteEditorInput() } }
                function indentSelection(reverse) {
                    const anchor = cursorPosition === selectionStart ? selectionEnd : selectionStart
                    const result = editing.indent(textDocument, anchor, cursorPosition, reverse)
                    select(result.anchor, result.position)
                }
                Keys.onTabPressed: event => { indentSelection(false); event.accepted = true }
                Keys.onBacktabPressed: event => { indentSelection(true); event.accepted = true }
                ScriptEditing { id: editing }
                ScriptHighlighter { textDocument: code.textDocument; language: Scripts.draft.language || "powershell"; dark: Settings.dark }
            }
        }
        ToolButton { objectName: "scriptAdvancedToggle"; text: (editor.advancedExpanded ? "▾ " : "▸ ")+"运行配置与环境"; onClicked: editor.advancedExpanded=!editor.advancedExpanded
            Accessible.name: "运行配置与环境"; Accessible.role: Accessible.Button
            contentItem: Label { text: parent.text; color: Theme.accent; font.pixelSize: 13 }
        }
        ScrollView { id: advancedScroll; Layout.fillWidth: true; Layout.minimumHeight: 0; Layout.maximumHeight: editor.height < 750 ? 130 : 190; Layout.preferredHeight: Math.min(Layout.maximumHeight,advancedColumn.implicitHeight); visible: editor.advancedExpanded; clip: true; contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.vertical.active: true
        ColumnLayout { id: advancedColumn; width: advancedScroll.availableWidth; spacing: 10
        RowLayout { Layout.fillWidth: true
            Field { Layout.fillWidth: true; placeholderText: Scripts.draft.useOutputDirectoryAsWorkingDirectory ? "工作目录（留空使用本次输出目录）" : "工作目录（留空使用用户目录）"; text: Scripts.draft.workingDirectory || ""; onTextEdited: Scripts.updateDraft("workingDirectory",text) }
            ActionButton { text: "选择目录"; onClicked: { const path=App.chooseDirectory(); if(path) Scripts.updateDraft("workingDirectory",path) } }
        }
        CheckBox { text: "未指定工作目录时，在本次输出目录运行"; checked: !!Scripts.draft.useOutputDirectoryAsWorkingDirectory; onToggled: Scripts.updateDraft("useOutputDirectoryAsWorkingDirectory",checked) }
        RowLayout { Layout.fillWidth: true
            Label { text: "超时 / 秒" }
            SpinBox { from: 0; to: 86400; value: Scripts.draft.timeoutSeconds === undefined ? 300 : Scripts.draft.timeoutSeconds; editable: true; onValueModified: Scripts.updateDraft("timeoutSeconds",value) }
            CheckBox { text: "运行前确认"; checked: Scripts.draft.confirmBeforeRun || false; onToggled: Scripts.updateDraft("confirmBeforeRun",checked) }
            CheckBox { text: "交互会话"; checked: Scripts.draft.executionMode === "interactive"; onToggled: Scripts.updateDraft("executionMode",checked ? "interactive" : "process") }
        }
        RowLayout { Layout.fillWidth: true
            Field { Layout.fillWidth: true; placeholderText: "输出目录（留空为每次运行创建独立目录）"; text: Scripts.draft.outputDirectory || ""; onTextEdited: Scripts.updateDraft("outputDirectory",text) }
            ActionButton { text: "选择目录"; onClicked: { const path=App.chooseDirectory(); if(path) Scripts.updateDraft("outputDirectory",path) } }
            ActionButton { text: "环境变量 ("+Scripts.draftEnvironment.length+")"; onClicked: environmentDialog.open() }
            ActionButton { text: "命令行参数"; visible: Scripts.draft.language === "python"; onClicked: argumentsDialog.open() }
        }
        Label { Layout.fillWidth: true; text: "脚本通过 UTERMINAL_OUTPUT_DIR 读取输出目录；相对目录以工作目录为基准。"; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
        }
        }
        RowLayout { Layout.fillWidth: true
            Label { text: "草稿自动保存在本地"; color: Theme.muted; Layout.fillWidth: true; font.pixelSize: 12 }
            ActionButton { text: "关闭"; onClicked: editor.close() }
            ActionButton { objectName: "scriptSaveButton"; text: "保存脚本"; primary: true; onClicked: { if(Scripts.saveDraft()) editor.close() } }
            ActionButton { text: "检查 Python 依赖"; visible: Scripts.draft.language === "python"; enabled: Plugins.pythonReady && !Python.busy; onClicked: { Python.probe(Scripts.draft.code,Scripts.draft.workingDirectory || "");diagnostics.open() } }
        }
    }
    AppDialog {
        id: argumentsDialog; objectName: "scriptArgumentsDialog"; title: "Python 命令行参数"; anchors.centerIn: parent; modal: true
        width: Math.min(650,editor.width-30); height: Math.min(480,editor.height-40); standardButtons: Dialog.Close
        ColumnLayout { anchors.fill: parent
            Label { text: "每项作为一个完整参数传入 sys.argv，空格无需额外引号；支持与代码相同的参数占位符。"; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.muted }
            Label { visible: !!Scripts.draft.legacyConditionalArguments; text: "此迁移脚本保留旧版条件语法：?参数名:内容。参数值非空时才传入该项；不存在或空值时省略。"; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.muted }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6; model: Scripts.draft.arguments || []
                delegate: RowLayout { required property string modelData; required property int index; width: ListView.view.width
                    Label { text: index+1; color: Theme.muted }
                    Field { Layout.fillWidth: true; text: modelData; placeholderText: "空参数"; onEditingFinished: Scripts.setDraftArgument(index,text) }
                    ActionButton { text: "删除"; focusPolicy: Qt.NoFocus; onClicked: Scripts.removeDraftArgument(index) }
                }
            }
            ActionButton { text: "添加参数"; onClicked: Scripts.setDraftArgument((Scripts.draft.arguments || []).length,"") }
        }
    }
    AppDialog { id: environmentDialog; anchors.centerIn: parent; width: Math.min(650,editor.width-30); height: Math.min(500,editor.height-40); title: "脚本环境变量"; modal: true; standardButtons: Dialog.Close
        ColumnLayout { anchors.fill: parent; spacing: 10
            Label { text: "仅影响此脚本进程。选择一项后可修改其值；Python 环境和输出目录由应用管理。"; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.muted }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: Scripts.draftEnvironment; spacing: 6
                delegate: RowLayout { required property var modelData; width: ListView.view.width
                    Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                    ActionButton { text: "编辑"; onClicked: { envName.text=modelData.name; envValue.text=modelData.value } }
                    ActionButton { text: "删除"; onClicked: Scripts.removeDraftEnvironment(modelData.name) }
                }
            }
            Field { id: envName; Layout.fillWidth: true; placeholderText: "变量名称，例如 API_ENDPOINT" }
            ScrollView { Layout.fillWidth: true; Layout.preferredHeight: 90
                TextArea { id: envValue; placeholderText: "变量值（允许多行）"; textFormat: TextEdit.PlainText; wrapMode: TextEdit.Wrap; selectByMouse: true }
            }
            ActionButton { text: "添加或更新"; primary: true; enabled: envName.text.length>0; onClicked: { if(Scripts.setDraftEnvironment(envName.text,envValue.text)){ envName.clear(); envValue.clear() } } }
        }
    }
    AppDialog { id: diagnostics; anchors.centerIn: parent; title: "Python 依赖检查"; width: 530; modal: true; standardButtons: Dialog.Close
        ColumnLayout { width: parent.width; spacing: 12
            Label { text: Python.status; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Label { text: Python.diagnostics.syntaxError || ""; visible: text !== ""; color: "#e05252"; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Label { text: "缺少模块："+(Python.diagnostics.missing || []).join(", "); wrapMode: Text.Wrap; Layout.fillWidth: true }
            Label { text: "建议安装："+(Python.diagnostics.suggestions || []).join(", "); wrapMode: Text.Wrap; Layout.fillWidth: true }
            Repeater { model: Python.diagnostics.errors || []
                Label { required property var modelData; text: modelData.module+"："+modelData.message; color: "#e05252"; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
            Label { text: "静态检查无法完整识别动态导入。安装前可在设置中核对或手动指定包名。"; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
            ActionButton { text: "安装建议依赖"; enabled: !Python.busy && (Python.diagnostics.suggestions || []).length > 0; onClicked: Python.installSuggested() }
        }
    }
}
