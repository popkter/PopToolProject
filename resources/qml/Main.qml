import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UTerminal
ApplicationWindow {
    id: appWindow
    width: 1362; height: 1024; minimumWidth: 1000; minimumHeight: 700
    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
           | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint
    topPadding: 0; leftPadding: 0; rightPadding: 0; bottomPadding: 0
    visible: false
    title: App.elevated ? "UTerminal · 管理员" : "UTerminal"
    color: "transparent"
    readonly property color chromeBackground: Settings.dark ? "#202020" : "#f3f3f3"
    readonly property color chromeIdle: Settings.dark ? "#353535" : "#e5e5e5"
    readonly property color chromeSelected: Settings.dark ? "#3b3b3b" : "#dfdfdf"
    readonly property color chromeText: Settings.dark ? "#f5f5f5" : "#1a1a1a"
    readonly property color chromeMuted: Settings.dark ? "#b8b8b8" : "#616161"
    readonly property color chromeAccent: Theme.accent
    function syncTitleBar() { App.updateTitleBar(appWindow,Settings.dark,appWindow.chromeBackground,appWindow.chromeText) }
    function openTerminal() { App.page = 1; Sessions.ensureTab() }
    Component.onCompleted: { syncTitleBar(); Qt.callLater(Sessions.ensureTab); if(Updates.readyToInstall) Qt.callLater(Updates.requestInstallation) }
    Connections { target: Settings; function onChanged() { Qt.callLater(appWindow.syncTitleBar) } }
    palette.window: Theme.background; palette.base: Theme.surface; palette.text: Theme.text; palette.windowText: Theme.text
    palette.button: Theme.surface; palette.buttonText: Theme.text; palette.highlight: Theme.accent; palette.highlightedText: "white"
    onClosing: close => { close.accepted = false; App.requestQuit() }
    Item {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; anchors.leftMargin: 42; anchors.topMargin: 42; color: Theme.background }
        Rectangle {
            id: topBar
            anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: App.captionInset; anchors.top: parent.top
            height: App.captionHeight; color: appWindow.chromeBackground
            Item {
                id: mainTitleBarDragRegion
                objectName: "mainTitleBarDragRegion"
                anchors.left: parent.left; anchors.leftMargin: 42; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.rightMargin: 0
                visible: App.page !== 1
                Component.onCompleted: App.registerCaptionItem(mainTitleBarDragRegion)
                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: if(active) App.startSystemMove(appWindow)
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onDoubleTapped: appWindow.visibility === Window.Maximized ? appWindow.showNormal() : appWindow.showMaximized()
                }
            }
        }
        Rectangle {
            id: navigation
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 42; color: appWindow.chromeBackground; z: 20
            Image {
                objectName: "navigationAppIcon"
                anchors.horizontalCenter: parent.horizontalCenter
                y: 5
                width: 32; height: 32
                source: App.resources + "icons/app-icon-ui.png"; fillMode: Image.PreserveAspectFit
            }
            Repeater {
                model: [{name:"terminal",title:"终端",page:1},{name:"code",title:"自定义",page:0}]
                delegate: ToolButton {
                    required property var modelData
                    required property int index
                    x: 5; y: App.captionHeight + index * 37; width: 32; height: 32
                    Accessible.name: modelData.title
                    background: Rectangle { radius: 5; color: App.page === modelData.page ? appWindow.chromeSelected : parent.hovered ? appWindow.chromeIdle : "transparent" }
                    contentItem: Icon { name: modelData.name; font.pixelSize: 17; color: App.page === modelData.page ? appWindow.chromeAccent : appWindow.chromeMuted }
                    onClicked: modelData.page === 1 ? appWindow.openTerminal() : App.page = modelData.page
                }
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: settingsButton.top; anchors.bottomMargin: 8
                width: 32; height: App.elevated ? 132 : 92
                Text {
                    anchors.centerIn: parent
                    text: App.elevated ? "UTerminal · 管理员" : "UTerminal"
                    rotation: -90; color: appWindow.chromeMuted; font.pixelSize: 12
                }
            }
            ToolButton {
                id: settingsButton
                x: 5; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; width: 32; height: 32
                Accessible.name: "设置"
                background: Rectangle { radius: 5; color: App.page === 2 ? appWindow.chromeSelected : parent.hovered ? appWindow.chromeIdle : "transparent" }
                contentItem: Icon { name: "settings"; font.pixelSize: 17; color: App.page === 2 ? appWindow.chromeAccent : appWindow.chromeMuted }
                onClicked: App.page = 2
            }
        }
        StackLayout {
            anchors.left: navigation.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.topMargin: App.page === 1 ? 0 : App.captionHeight; currentIndex: App.page
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
    AppDialog { id: updateDialog; objectName: "updateConfirmationDialog"; title: "立即更新"; anchors.centerIn: parent; modal: true; width: Math.min(560,appWindow.width-48); standardButtons: Dialog.NoButton; closePolicy: Popup.NoAutoClose
        ColumnLayout { anchors.fill: parent; spacing: 8
            Label { text: "更新包已经下载完毕，是否立即重启更新？"; color: Theme.muted; font.pixelSize: 15; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Label { text: "立即更新会关闭正在运行的终端和脚本。"; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
        footer: Item { implicitHeight: 70
            RowLayout { anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.bottomMargin: 20; spacing: 12
                ActionButton { text: "立即更新"; Layout.fillWidth: true; onClicked: { if(Updates.prepareInstallation()){ updateDialog.close();App.quitNow() } } }
                ActionButton { text: "稍后更新"; primary: true; Layout.fillWidth: true; onClicked: updateDialog.close() }
            }
        }
    }
    Popup { id: notification; x: (appWindow.width-width)/2; y: appWindow.height-height-30; width: Math.min(700,appWindow.width-80); padding: 16
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
    Connections { target: Plugins; function onChanged() { if(App.page === 1 && Plugins.powerShellReady && Sessions.count === 0) Qt.callLater(Sessions.ensureTab) } }
    Connections { target: Updates; function onInstallationRequested() { updateDialog.open() } }
    Shortcut { sequence: "Ctrl+T"; onActivated: App.page === 1 ? Sessions.newTab() : appWindow.openTerminal() }
    Shortcut { sequence: "Ctrl+Tab"; enabled: App.page === 1; onActivated: Sessions.nextTab() }
    Shortcut { sequence: "Ctrl+F"; enabled: App.page === 1 && !!Sessions.focusedPane; onActivated: Sessions.focusedPane.terminal.openSearch() }
    Shortcut { objectName: "showScriptsShortcut"; sequence: "Ctrl+Q"; onActivated: App.page = 0 }
}
