import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UTerminal
Item {
    id: page
        Rectangle { id: tabBar; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 48; color: Theme.background
            RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4
                ListView { id: tabs; Layout.fillWidth: true; Layout.fillHeight: true; orientation: ListView.Horizontal; model: Sessions; clip: true; spacing: 4
                    delegate: Rectangle { required property int index; required property string tabTitle; required property bool active; width: 220; height: 40; y: 8; radius: 8; color: active ? "#2b313d" : Theme.field
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 12
                            Text { text: tabTitle; color: active ? "#eef1f6" : Theme.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            ToolButton { text: "×"; palette.buttonText: active ? "white" : Theme.muted; onClicked: Sessions.closeTab(index) }
                        }
                        TapHandler { acceptedButtons: Qt.LeftButton; onTapped: Sessions.currentIndex=index }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { tabMenu.tabIndex=index;tabMenu.popup() } }
                    }
                }
                ToolButton { text: "+"; onClicked: Sessions.newTab(); ToolTip.visible: hovered; ToolTip.text: "新标签 Ctrl+T" }
                ToolButton { contentItem: Icon { name: "view_column" } onClicked: Sessions.split(false); ToolTip.visible: hovered; ToolTip.text: "左右分屏" }
                ToolButton { contentItem: Icon { name: "table_rows" } onClicked: Sessions.split(true); ToolTip.visible: hovered; ToolTip.text: "上下分屏" }
            }
        }
        Rectangle { anchors.top: tabBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; color: "#2b313d"
            SplitView { id: splitArea; anchors.fill: parent; orientation: Sessions.vertical ? Qt.Vertical : Qt.Horizontal; visible: Sessions.panes.length > 0
                Instantiator { model: Sessions.panes
                    onObjectAdded: (index,object) => { splitArea.insertItem(index,object); object.visible=true }
                    onObjectRemoved: (index,object) => splitArea.removeItem(object)
                    delegate: Rectangle { required property var modelData; required property int index; implicitWidth: 480; implicitHeight: 300; SplitView.fillWidth: index === 0; SplitView.fillHeight: index === 0; SplitView.preferredWidth: splitArea.width/Math.max(1,Sessions.panes.length); SplitView.preferredHeight: splitArea.height/Math.max(1,Sessions.panes.length); SplitView.minimumWidth: 120; SplitView.minimumHeight: 80; color: "#2b313d"; border.width: 1; border.color: Sessions.focusedPane === modelData ? Theme.accent : "#384250"
                        PaneHost { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: paneStatus.top; anchors.margins: 7; pane: modelData }
                        Rectangle { id: paneStatus; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 1; height: 24; color: Theme.surface
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
    Menu { id: contextMenu
        MenuItem { text: "复制"; enabled: Sessions.menuText.length > 0; onTriggered: Sessions.copyMenuSelection() }
        MenuItem { text: "粘贴"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.menuPane.terminal.pasteClipboard() }
        MenuItem { text: "清空"; enabled: !!Sessions.menuPane; onTriggered: Sessions.menuPane.terminal.clearDisplay() }
        MenuSeparator {}
        MenuItem { text: "停止当前命令"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.interrupt(Sessions.menuPane) }
        MenuItem { text: "结束会话"; enabled: Sessions.menuPane && Sessions.menuPane.running; onTriggered: Sessions.endPane(Sessions.menuPane) }
        MenuItem { text: "关闭窗格"; enabled: !!Sessions.menuPane; onTriggered: Sessions.closePane(Sessions.menuPane) }
        MenuSeparator {}
        MenuItem { text: "添加为自定义脚本"; enabled: Sessions.menuText.trim().length > 0; onTriggered: Sessions.draftFromSelection() }
    }
    Menu { id: tabMenu; property int tabIndex: -1
        MenuItem { text: "重命名"; onTriggered: renameDialog.open() }
        MenuItem { text: "关闭"; onTriggered: Sessions.closeTab(tabMenu.tabIndex) }
        MenuItem { text: "关闭其他标签"; onTriggered: Sessions.closeOthers(tabMenu.tabIndex) }
        MenuItem { text: "关闭右侧标签"; onTriggered: Sessions.closeRight(tabMenu.tabIndex) }
    }
    Dialog { id: renameDialog; title: "重命名标签"; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Ok | Dialog.Cancel
        Field { id: tabName; placeholderText: "标签名称" }
        onAccepted: Sessions.renameTab(tabMenu.tabIndex,tabName.text)
    }
    Connections { target: Sessions; function onContextMenuRequested(x,y) { const point=page.mapFromItem(null,x,y);contextMenu.popup(point.x,point.y) } }
}
