import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UTerminal
Item {
    id: page
        Rectangle { id: tabBar; objectName: "terminalTabBar"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 42; color: Settings.dark ? Theme.surface : "#f7f8fa"
                readonly property real captionInset: Math.max(138,SafeArea.margins.right)
                readonly property real tabViewportLimit: Math.max(0,width-captionInset-52)
                ListView { id: tabs; objectName: "terminalTabs"; x: 0; y: 5; width: Math.min(contentWidth,tabBar.tabViewportLimit); height: 32; orientation: ListView.Horizontal; model: Sessions; clip: true; spacing: 7
                    currentIndex: Sessions.currentIndex
                    highlightMoveDuration: 0
                    function revealCurrentTab() {
                        if (currentIndex < 0 || currentIndex >= count || width <= 0) return
                        forceLayout()
                        positionViewAtIndex(currentIndex, ListView.Contain)
                    }
                    // Coalesce model and geometry changes, after delegate widths settle.
                    onCurrentIndexChanged: Qt.callLater(revealCurrentTab)
                    onCountChanged: Qt.callLater(revealCurrentTab)
                    onWidthChanged: Qt.callLater(revealCurrentTab)
                    onContentWidthChanged: Qt.callLater(revealCurrentTab)
                    delegate: Rectangle { required property int index; required property string tabTitle; required property bool active; width: 180; height: tabs.height; radius: 8; color: active ? Settings.terminalBackground : Settings.dark ? Theme.border : "#e9e9e9"
                        Text { anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; text: tabTitle; color: active ? Settings.terminalForeground : Settings.dark ? Theme.text : "#0a0a0a"; font.pixelSize: 12; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        ToolButton {
                            id: closeTabButton
                            objectName: "closeTab_" + index
                            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; text: "×"
                            contentItem: Text { text: closeTabButton.text; color: active ? Settings.terminalForeground : Settings.dark ? Theme.text : "#0a0a0a"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 7; color: closeTabButton.hovered ? (active ? "#25ffffff" : Settings.dark ? Theme.field : "#d7d7d7") : "transparent"; border.width: closeTabButton.activeFocus ? 1 : 0; border.color: Theme.accent }
                            onClicked: Sessions.closeTab(index)
                        }
                        TapHandler { acceptedButtons: Qt.LeftButton; onTapped: Sessions.currentIndex=index }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { tabMenu.tabIndex=index;tabMenu.popup() } }
                    }
                }
            ToolButton {
                id: newTabButton; objectName: "newTerminalTab"
                x: tabs.x+tabs.width+(tabs.count > 0 ? 5 : 0); y: 5; width: 32; height: 32
                background: Rectangle { radius: 8; color: newTabButton.down ? "#1262cb" : newTabButton.hovered ? "#3489f7" : "#1877f2" }
                contentItem: Icon { name: "add"; font.pixelSize: 18; color: "white" }
                onClicked: Sessions.newTab()
                ToolTip.visible: hovered; ToolTip.text: "新标签 Ctrl+T"; Accessible.name: "新标签"
            }
            Item {
                id: titleBarDragRegion; objectName: "titleBarDragRegion"
                anchors.left: newTabButton.right; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: tabBar.captionInset
                anchors.top: parent.top; anchors.bottom: parent.bottom
                DragHandler { target: null; acceptedButtons: Qt.LeftButton; onActiveChanged: if(active) App.startSystemMove(ApplicationWindow.window) }
                TapHandler { acceptedButtons: Qt.LeftButton; onDoubleTapped: ApplicationWindow.window.visibility === Window.Maximized ? ApplicationWindow.window.showNormal() : ApplicationWindow.window.showMaximized() }
            }
        }
        Rectangle { anchors.top: tabBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; color: Settings.terminalBackground
            SplitView { id: splitArea; anchors.fill: parent; orientation: Sessions.vertical ? Qt.Vertical : Qt.Horizontal; visible: Sessions.panes.length > 0
                Instantiator { model: Sessions.panes
                    onObjectAdded: (index,object) => { splitArea.insertItem(index,object); object.visible=true }
                    onObjectRemoved: (index,object) => splitArea.removeItem(object)
                    delegate: Rectangle { required property var modelData; required property int index; implicitWidth: 480; implicitHeight: 300; SplitView.fillWidth: index === 0; SplitView.fillHeight: index === 0; SplitView.preferredWidth: splitArea.width/Math.max(1,Sessions.panes.length); SplitView.preferredHeight: splitArea.height/Math.max(1,Sessions.panes.length); SplitView.minimumWidth: 120; SplitView.minimumHeight: 80; color: Settings.terminalBackground; border.width: Sessions.panes.length > 1 ? 1 : 0; border.color: Settings.dark ? Theme.border : "#abaFB7"
                        PaneHost { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: paneStatus.top; pane: modelData }
                        Rectangle { id: paneStatus; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 24; color: Settings.terminalBackground
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 12
                                Text { text: modelData.runtimeLabel; color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: modelData.stateLabel; color: modelData.running ? Theme.accent : Theme.muted; font.pixelSize: 10 }
                                ToolButton { objectName: "closePane_"+index; visible: Sessions.panes.length>1; implicitHeight: 22; implicitWidth: 24; text: "×"; onClicked: Sessions.closePane(modelData); ToolTip.visible: hovered; ToolTip.text: "关闭此窗格" }
                            }
                        }
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                            width: Math.min(parent.width-16,440); height: 44; radius: 6; color: Theme.surface
                            visible: modelData.terminal.searchOpen
                            RowLayout { anchors.fill: parent; anchors.margins: 4; spacing: 2
                                TextField {
                                    id: searchField; Layout.fillWidth: true; Layout.minimumWidth: 30
                                    placeholderText: "查找文本"; text: modelData.terminal.searchText; selectByMouse: true
                                    onTextEdited: modelData.terminal.searchText=text
                                    onAccepted: modelData.terminal.nextSearch(false)
                                    Keys.onEscapePressed: modelData.terminal.closeSearch()
                                    Keys.onPressed: (event) => { if(event.key === Qt.Key_Return && (event.modifiers & Qt.ShiftModifier)) { modelData.terminal.nextSearch(true);event.accepted=true } }
                                }
                                Label { text: (modelData.terminal.searchIndex+1)+"/"+modelData.terminal.searchCount+(modelData.terminal.searchLimited?"+":""); color: Theme.muted }
                                ToolButton { text: "↑"; enabled: modelData.terminal.searchCount>0; onClicked: modelData.terminal.nextSearch(true); ToolTip.visible: hovered; ToolTip.text: "上一个 Shift+Enter" }
                                ToolButton { text: "↓"; enabled: modelData.terminal.searchCount>0; onClicked: modelData.terminal.nextSearch(false); ToolTip.visible: hovered; ToolTip.text: "下一个 Enter" }
                                ToolButton { text: "×"; onClicked: modelData.terminal.closeSearch(); ToolTip.visible: hovered; ToolTip.text: "关闭查找 Esc" }
                            }
                            Connections { target: modelData.terminal; function onSearchRequested() { searchField.forceActiveFocus();searchField.selectAll() } }
                        }
                    }
                }
            }
            ColumnLayout { anchors.centerIn: parent; spacing: 20; visible: Sessions.panes.length === 0
                Icon { name: "terminal"; font.pixelSize: 48; color: "#9aaac0"; Layout.alignment: Qt.AlignHCenter }
                Label { text: Plugins.powerShellReady ? "打开新的 PowerShell 终端" : "终端需要 PowerShell 7 插件"; color: "#eef1f6"; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
                Label { text: Plugins.powerShellReady ? "每个标签和窗格都有独立会话" : "安装由你主动开始，Python 并非终端的必需插件。"; color: "#9aaac0"; Layout.alignment: Qt.AlignHCenter }
                ActionButton { text: Plugins.powerShellReady ? "打开终端" : "安装 PowerShell 7"; primary: true; Layout.alignment: Qt.AlignHCenter; onClicked: Plugins.powerShellReady ? Sessions.newTab() : App.showPlugin("powershell") }
            }
        }
    AppMenu { id: contextMenu; objectName: "terminalContextMenu"
        AppMenuItem { text: "复制"; shortcutHint: "Ctrl+C"; enabled: Sessions.menuText.length > 0; onTriggered: Sessions.copyMenuSelection() }
        AppMenuItem { text: "粘贴"; shortcutHint: "Ctrl+V"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.menuPane.terminal.pasteClipboard() }
        AppMenuItem { text: "清空"; enabled: !!Sessions.menuPane; onTriggered: Sessions.menuPane.terminal.clearDisplay() }
        AppMenuItem { objectName: "historyPredictionMenuItem"; text: Sessions.historyPrediction ? "关闭历史" : "显示历史"; enabled: !!Sessions.menuPane; onTriggered: Sessions.toggleHistoryPrediction() }
        AppMenuSeparator {}
        AppMenuItem { objectName: "splitTerminalHorizontal"; text: "左右分屏"; enabled: Sessions.panes.length > 0; onTriggered: Sessions.split(false) }
        AppMenuItem { objectName: "splitTerminalVertical"; text: "上下分屏"; enabled: Sessions.panes.length > 0; onTriggered: Sessions.split(true) }
        AppMenuSeparator {}
        AppMenuItem { text: "停止当前命令"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.interrupt(Sessions.menuPane) }
        AppMenuItem { text: "结束会话"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.endPane(Sessions.menuPane) }
        AppMenuItem { text: "关闭窗格"; enabled: !!Sessions.menuPane; onTriggered: Sessions.closePane(Sessions.menuPane) }
        AppMenuSeparator {}
        AppMenuItem { text: "添加为自定义脚本"; enabled: Sessions.menuText.trim().length > 0; onTriggered: Sessions.draftFromSelection() }
    }
    AppMenu { id: tabMenu; objectName: "terminalTabMenu"; property int tabIndex: -1
        AppMenuItem { text: "重命名"; onTriggered: renameDialog.open() }
        AppMenuItem { text: "关闭"; onTriggered: Sessions.closeTab(tabMenu.tabIndex) }
        AppMenuItem { text: "关闭其他标签"; onTriggered: Sessions.closeOthers(tabMenu.tabIndex) }
        AppMenuItem { text: "关闭右侧标签"; onTriggered: Sessions.closeRight(tabMenu.tabIndex) }
    }
    AppDialog { id: renameDialog; title: "重命名标签"; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Ok | Dialog.Cancel
        Field { id: tabName; width: parent.width; placeholderText: "标签名称" }
        onAccepted: Sessions.renameTab(tabMenu.tabIndex,tabName.text)
    }
    Connections { target: Sessions; function onContextMenuRequested(x,y) { const point=page.mapFromItem(null,x,y);contextMenu.popup(point.x,point.y) } }
}
