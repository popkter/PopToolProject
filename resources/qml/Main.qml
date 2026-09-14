import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UTerminal
ApplicationWindow {
    id: window
    width: 1362; height: 1024; minimumWidth: 1000; minimumHeight: 700
    visible: true
    title: App.elevated ? "UTerminal · 管理员" : "UTerminal"
    color: Theme.background
    function syncTitleBar() { App.updateTitleBar(window,Settings.dark,Theme.surface,Theme.text) }
    Component.onCompleted: syncTitleBar()
    Connections { target: Settings; function onChanged() { Qt.callLater(window.syncTitleBar) } }
    palette.window: Theme.background; palette.base: Theme.surface; palette.text: Theme.text; palette.windowText: Theme.text
    palette.button: Theme.surface; palette.buttonText: Theme.text; palette.highlight: Theme.accent; palette.highlightedText: "white"
    onClosing: close => { close.accepted = false; App.requestQuit() }
    RowLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {
            Layout.preferredWidth: 52; Layout.fillHeight: true; color: Theme.surface
            Rectangle { width: 1; height: parent.height; anchors.right: parent.right; color: Theme.border }
            ColumnLayout {
                anchors.fill: parent; anchors.topMargin: 14; anchors.bottomMargin: 12; spacing: 8
                Image { source: App.resources + "icons/app-icon-ui.png"; Layout.preferredWidth: 28; Layout.preferredHeight: 28; Layout.alignment: Qt.AlignHCenter; fillMode: Image.PreserveAspectFit }
                Repeater {
                    model: [{name:"terminal",title:"终端",page:1},{name:"code",title:"自定义",page:0}]
                    delegate: ToolButton {
                        required property var modelData
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: Qt.AlignHCenter
                        ToolTip.visible: hovered; ToolTip.text: modelData.title
                        background: Rectangle { radius: 6; color: App.page === modelData.page ? Theme.selected : parent.hovered ? Theme.field : "transparent" }
                        contentItem: Icon { name: modelData.name; font.pixelSize: 18; color: App.page === modelData.page ? Theme.accent : Theme.muted }
                        onClicked: App.page = modelData.page
                    }
                }
                Item { Layout.fillHeight: true }
                ToolButton {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: Qt.AlignHCenter
                    ToolTip.visible: hovered; ToolTip.text: "设置"
                    background: Rectangle { radius: 6; color: App.page === 2 ? Theme.selected : parent.hovered ? Theme.field : "transparent" }
                    contentItem: Icon { name: "settings"; font.pixelSize: 18; color: App.page === 2 ? Theme.accent : Theme.muted }
                    onClicked: App.page = 2
                }
            }
        }
        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: App.page
            ScriptsPage {}
            TerminalPage {}
            SettingsPage {}
        }
    }
    ScriptEditor { id: editor }
    PluginDialog { id: pluginDialog; objectName: "globalPluginDialog" }
    PythonEnvironmentDialog { id: environmentDialog; objectName: "globalPythonEnvironment" }
    AppDialog { id: migrationDialog; title: "切换 Python 版本"; anchors.centerIn: parent; width: 620; height: 460; modal: true; closePolicy: Popup.NoAutoClose
        ColumnLayout { anchors.fill: parent; spacing: 14
            Label { text: "目标版本："+Python.migrationTarget+"。旧会话继续使用原环境。"; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Label { text: "是否在目标版本重新安装以下依赖？失败时保留当前活动版本。"; Layout.fillWidth: true; wrapMode: Text.Wrap }
            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true; TextArea { text: Python.requirements || "（当前没有额外依赖）"; readOnly: true; font.family: Settings.fontFamily; wrapMode: TextEdit.Wrap } }
            RowLayout { Layout.fillWidth: true
                ActionButton { text: "取消"; onClicked: { Python.cancel();migrationDialog.close() } }
                Item { Layout.fillWidth: true }
                ActionButton { text: "不迁移，仅验证并切换"; onClicked: { Python.confirmSwitch(false);migrationDialog.close();environmentDialog.open() } }
                ActionButton { text: "重新安装并切换"; primary: true; onClicked: { Python.confirmSwitch(true);migrationDialog.close();environmentDialog.open() } }
            }
        }
    }
    Connections { target: Python; function onSwitchConfirmationRequested() { migrationDialog.open() } }
    AppDialog { id: replaceDialog; title: "替换已有脚本"; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Yes | Dialog.No
        Label { text: "已有相同 ID 的脚本。备份后替换其内容？"; width: parent.width; wrapMode: Text.Wrap; color: Theme.muted }
        onAccepted: App.importClipboard(true)
    }
    AppDialog { id: quitDialog; title: "退出应用"; destructive: true; acceptText: "退出"; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Yes | Dialog.No
        Label { text: "仍有运行任务、终端会话或插件安装。退出会结束它们。"; width: parent.width; wrapMode: Text.Wrap; color: Theme.muted }
        onAccepted: App.quitNow()
    }
    AppDialog { id: runDialog; property string message; title: "运行确认"; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Yes | Dialog.No
        Label { text: runDialog.message; width: parent.width; wrapMode: Text.Wrap; color: Theme.muted }
        onAccepted: Runs.confirmRun(); onRejected: Runs.cancelRun()
    }
    AppDialog { id: pasteDialog; property string value; title: "粘贴多行文本？"; anchors.centerIn: parent; modal: true; width: 600; standardButtons: Dialog.Yes | Dialog.No
        ColumnLayout { anchors.fill: parent
            Label { text: "多行文本可能执行多条命令。请确认内容后粘贴。" }
            ScrollView { Layout.fillWidth: true; Layout.preferredHeight: 200; TextArea { text: pasteDialog.value; readOnly: true; font.family: Settings.fontFamily; wrapMode: TextEdit.Wrap } }
        }
        onAccepted: Sessions.acceptPaste(); onRejected: Sessions.cancelPaste()
    }
    Popup { id: notification; x: (window.width-width)/2; y: window.height-height-30; width: Math.min(700,window.width-80); padding: 16
        background: PopupSurface {}
        contentItem: Text { text: App.notice; color: Theme.text; wrapMode: Text.Wrap; font.pixelSize: 13 }
        Timer { id: notificationTimer; interval: 6000; onTriggered: notification.close() }
    }
    Connections { target: App
        function onEditorRequested() { editor.open() }
        function onPluginRequested(kind) { pluginDialog.kind=kind; pluginDialog.open() }
        function onReplaceImportRequested() { replaceDialog.open() }
        function onQuitConfirmationRequested() { quitDialog.open() }
        function onNoticeChanged() { notification.open(); notificationTimer.restart() }
    }
    Connections { target: Runs; function onConfirmationRequested(message) { runDialog.message=message;runDialog.open() } }
    Connections { target: Sessions; function onPasteConfirmationRequested(text) { pasteDialog.value=text;pasteDialog.open() } }
    Shortcut { sequence: "Ctrl+T"; enabled: App.page === 1; onActivated: Sessions.newTab() }
    Shortcut { sequence: "Ctrl+Tab"; enabled: App.page === 1; onActivated: Sessions.nextTab() }
    Shortcut { sequence: "Ctrl+F"; enabled: App.page === 1 && !!Sessions.focusedPane; onActivated: Sessions.focusedPane.terminal.openSearch() }
}
