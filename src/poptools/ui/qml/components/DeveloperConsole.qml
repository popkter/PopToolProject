pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PopTools.Terminal 1.0
import "../theme"

Item {
    id: root
    required property var controller

    function copySelectionOrInterrupt() {
        if (terminalView.hasSelection) terminalView.copySelection()
        else root.controller.interrupt()
        terminalView.forceActiveFocus()
    }
    function pasteClipboard() { terminalView.pasteClipboard(); terminalView.forceActiveFocus() }
    function clearTerminal() { root.controller.clear(); terminalView.forceActiveFocus() }

    Shortcut { sequence: "Ctrl+C"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.copySelectionOrInterrupt() }
    Shortcut { sequence: "Ctrl+Shift+C"; context: Qt.WindowShortcut; enabled: root.visible && terminalView.hasSelection; onActivated: terminalView.copySelection() }
    Shortcut { sequence: "Ctrl+V"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.pasteClipboard() }
    Shortcut { sequence: "Ctrl+Shift+V"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.pasteClipboard() }
    Shortcut { sequence: "Ctrl+L"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.clearTerminal() }

    Component.onDestruction: root.controller.terminalDetached()
    onVisibleChanged: if (visible) { root.controller.ensureStarted(); terminalView.forceActiveFocus() }

    Connections {
        target: root.controller
        function onTerminalData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalSnapshotData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalResetRequested(tabId) { terminalView.resetSession(tabId) }
        function onTerminalSessionRemoved(tabId) { terminalView.removeSession(tabId) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space28
        anchors.rightMargin: Theme.space28
        anchors.topMargin: 0
        anchors.bottomMargin: Theme.space28
        spacing: Theme.space16

        WorkspacePageHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            Layout.minimumHeight: 68
            Layout.maximumHeight: 68
            title: "终端"
            description: "执行命令并查看输出"
            titlePixelSize: 28
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.consoleBackground
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: Theme.consoleHeaderBackground

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: terminalTabs.implicitWidth
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: terminalTabs
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Repeater {
                                    model: root.controller.terminalTabs
                                    delegate: Rectangle {
                                        id: tab
                                        required property var modelData
                                        width: 146; height: 35; radius: 8
                                        color: modelData.active ? "#313947" : "transparent"
                                        RowLayout {
                                            z: 1
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: tab.modelData.active ? Theme.consoleText : Theme.consoleMuted }
                                            Text { Layout.fillWidth: true; text: tab.modelData.title || "Android 调试"; color: Theme.consoleText; font.pixelSize: Theme.fontBody; elide: Text.ElideRight }
                                            MaterialIcon { visible: root.controller.terminalTabs.length > 1; icon: "close"; iconSize: 15; color: Theme.consoleMuted
                                                MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true; root.controller.closeTerminalTab(tab.modelData.tabId) } }
                                            }
                                        }
                                        MouseArea { anchors.fill: parent; z: 0; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.activateTerminalTab(tab.modelData.tabId) }
                                    }
                                }
                                Rectangle {
                                    width: 36; height: 40; radius: 8; color: addMouse.containsMouse ? "#3A4657" : "#313947"
                                    MaterialIcon { anchors.centerIn: parent; icon: "add"; iconSize: 20; color: Theme.consoleText }
                                    MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.controller.canCreateTerminalTab; onClicked: root.controller.createTerminalTab() }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 54; Layout.preferredHeight: 32; radius: 8
                            color: clearMouse.containsMouse ? "#3A4657" : "#343C48"
                            Text { anchors.centerIn: parent; text: "清空"; color: Theme.consoleText; font.pixelSize: Theme.fontCaption }
                            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearTerminal() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 32; radius: 8
                            color: restartMouse.containsMouse ? "#3A4657" : "#343C48"
                            Text { anchors.centerIn: parent; text: "终端设置"; color: Theme.consoleText; font.pixelSize: Theme.fontCaption }
                            MouseArea { id: restartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.restart() }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TerminalView {
                        id: terminalView
                        anchors.fill: parent
                        anchors.margins: 16
                        sessionId: root.controller.activeTerminalTabId
                        fontSize: 14
                        focus: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "开发者终端"
                        Component.onCompleted: { root.controller.terminalReady(); forceActiveFocus() }
                        onInputGenerated: function(tabId, data) { root.controller.writeInputToTab(tabId, data) }
                        onTerminalSizeChanged: function(columns, rows) { root.controller.resizeTerminal(columns, rows) }
                        onContextMenuRequested: function(x, y) { terminalContextMenu.popup(x, y) }
                    }

                    ScrollBar {
                        anchors.top: terminalView.top; anchors.right: terminalView.right; anchors.bottom: terminalView.bottom
                        orientation: Qt.Vertical
                        policy: terminalView.scrollbackLineCount > 0 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        size: terminalView.rows / Math.max(terminalView.rows, terminalView.rows + terminalView.scrollbackLineCount)
                        position: terminalView.scrollbackLineCount > 0 ? (terminalView.scrollbackLineCount - terminalView.scrollOffset) / (terminalView.rows + terminalView.scrollbackLineCount) : 0
                    }

                    AppMenu {
                        id: terminalContextMenu
                        objectName: "terminalContextMenu"
                        AppMenuItem { text: "复制"; enabled: terminalView.hasSelection; onTriggered: terminalView.copySelection() }
                        AppMenuItem { text: "粘贴"; onTriggered: root.pasteClipboard() }
                        AppMenuSeparator {}
                        AppMenuItem { text: "全选"; onTriggered: terminalView.selectAll() }
                        AppMenuItem { text: "清屏"; onTriggered: root.clearTerminal() }
                        AppMenuItem { text: "停止当前命令"; destructive: true; enabled: root.controller.running; onTriggered: root.controller.interrupt() }
                    }
                }
            }
        }
    }
}
