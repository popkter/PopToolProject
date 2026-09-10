pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PopTools.Terminal 1.0
import "../theme"

Item {
    id: root
    required property var controller
    readonly property int terminalToolbarControlHeight: 40
    property string renamingTabId: ""
    property string lastPressedTabId: ""
    property double lastTabPressTime: 0

    function copySelectionOrInterrupt() {
        if (terminalView.hasSelection) terminalView.copySelection()
        else root.controller.interrupt()
        terminalView.forceActiveFocus()
    }
    function pasteClipboard() { terminalView.pasteClipboard(); terminalView.forceActiveFocus() }
    function clearTerminal() { root.controller.clear(); terminalView.forceActiveFocus() }
    function beginRename(tabId) { root.renamingTabId = tabId }
    function handleTabPress(tabId) {
        var now = Date.now()
        if (root.lastPressedTabId === tabId && now - root.lastTabPressTime <= 500) {
            root.lastPressedTabId = ""
            root.lastTabPressTime = 0
            root.beginRename(tabId)
            return
        }
        root.lastPressedTabId = tabId
        root.lastTabPressTime = now
        root.controller.activateTerminalTab(tabId)
    }
    function finishRename(tabId, title) {
        if (root.renamingTabId !== tabId)
            return
        root.controller.renameTerminalTab(tabId, title)
        root.renamingTabId = ""
        terminalView.forceActiveFocus()
    }
    function cancelRename(tabId) {
        if (root.renamingTabId !== tabId)
            return
        root.renamingTabId = ""
        terminalView.forceActiveFocus()
    }
    function tabIndex(tabId) {
        var tabs = root.controller.terminalTabs
        for (var index = 0; index < tabs.length; ++index) {
            if (tabs[index].tabId === tabId)
                return index
        }
        return -1
    }

    Shortcut { sequence: "Ctrl+C"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.copySelectionOrInterrupt() }
    Shortcut { sequence: "Ctrl+Shift+C"; context: Qt.WindowShortcut; enabled: root.visible && terminalView.hasSelection; onActivated: terminalView.copySelection() }
    Shortcut { sequence: "Ctrl+V"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.pasteClipboard() }
    Shortcut { sequence: "Ctrl+Shift+V"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.pasteClipboard() }
    Shortcut { sequence: "Ctrl+L"; context: Qt.WindowShortcut; enabled: root.visible; onActivated: root.clearTerminal() }
    Shortcut { sequence: "Ctrl+Shift+T"; context: Qt.WindowShortcut; enabled: root.visible && root.renamingTabId.length === 0 && root.controller.canCreateTerminalTab; onActivated: root.controller.createTerminalTab() }
    Shortcut { sequence: "Ctrl+Shift+W"; context: Qt.WindowShortcut; enabled: root.visible && root.renamingTabId.length === 0; onActivated: root.controller.closeTerminalTab(root.controller.activeTerminalTabId) }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.WindowShortcut; enabled: root.visible && root.renamingTabId.length === 0; onActivated: root.controller.activateRelativeTerminalTab(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; context: Qt.WindowShortcut; enabled: root.visible && root.renamingTabId.length === 0; onActivated: root.controller.activateRelativeTerminalTab(-1) }

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
                    radius: Theme.radiusMedium
                    color: Theme.consoleHeaderBackground

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.radiusMedium
                        color: parent.color
                    }

                    RowLayout {
                        z: 1
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
                                        width: 146; height: root.terminalToolbarControlHeight; radius: 8
                                        color: modelData.active ? "#313947" : "transparent"
                                        RowLayout {
                                            z: 1
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: tab.modelData.active ? Theme.consoleText : Theme.consoleMuted }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: root.renamingTabId !== tab.modelData.tabId
                                                text: tab.modelData.title || "Android 调试"
                                                color: Theme.consoleText
                                                font.pixelSize: Theme.fontBody
                                                elide: Text.ElideRight
                                            }
                                            TextField {
                                                id: renameField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                visible: root.renamingTabId === tab.modelData.tabId
                                                color: Theme.consoleText
                                                font.pixelSize: Theme.fontBody
                                                leftPadding: 6; rightPadding: 6; topPadding: 0; bottomPadding: 0
                                                selectByMouse: true
                                                background: Rectangle {
                                                    radius: 4
                                                    color: "#202733"
                                                    border.color: Theme.primary
                                                    border.width: 1
                                                }
                                                onVisibleChanged: if (visible) {
                                                    text = tab.modelData.title
                                                    forceActiveFocus()
                                                    selectAll()
                                                }
                                                onEditingFinished: root.finishRename(tab.modelData.tabId, text)
                                                Keys.onReturnPressed: function(event) {
                                                    root.finishRename(tab.modelData.tabId, text)
                                                    event.accepted = true
                                                }
                                                Keys.onEscapePressed: function(event) {
                                                    root.cancelRename(tab.modelData.tabId)
                                                    event.accepted = true
                                                }
                                            }
                                            PrimaryButton {
                                                visible: root.controller.terminalTabs.length > 1
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                compact: true
                                                text: "关闭终端标签"
                                                iconName: "close"
                                                glyphSize: 15
                                                tonal: true
                                                foregroundColor: Theme.consoleMuted
                                                color: hovered ? "#3A4657" : "transparent"
                                                border.width: 0
                                                radius: 4
                                                onClicked: root.controller.closeTerminalTab(tab.modelData.tabId)
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            z: 0
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: function(mouse) {
                                                if (mouse.button === Qt.LeftButton)
                                                    root.handleTabPress(tab.modelData.tabId)
                                            }
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    root.controller.activateTerminalTab(tab.modelData.tabId)
                                                    terminalTabContextMenu.tabId = tab.modelData.tabId
                                                    var position = tab.mapToItem(root, mouse.x, mouse.y)
                                                    terminalTabContextMenu.popup(position.x, position.y)
                                                }
                                            }
                                        }
                                    }
                                }
                                PrimaryButton {
                                    width: 36; height: root.terminalToolbarControlHeight; radius: 8
                                    compact: true; text: "新增终端标签"; iconName: "add"; glyphSize: 20
                                    tonal: true; foregroundColor: Theme.consoleText; border.width: 0
                                    color: hovered ? "#3A4657" : "#313947"
                                    enabled: root.controller.canCreateTerminalTab
                                    disabledOpacity: 1
                                    onClicked: root.controller.createTerminalTab()
                                }
                            }
                        }

                        PrimaryButton {
                            Layout.preferredWidth: 54; Layout.preferredHeight: root.terminalToolbarControlHeight; radius: 8
                            text: "清空"; iconName: "delete_sweep"; glyphSize: 14; contentSpacing: 3
                            tonal: true; foregroundColor: Theme.consoleText; labelFontSize: Theme.fontCaption; labelFontWeight: Font.Normal
                            border.width: 0; color: hovered ? "#3A4657" : "#343C48"
                            onClicked: root.clearTerminal()
                        }
                        PrimaryButton {
                            Layout.preferredWidth: 80; Layout.preferredHeight: root.terminalToolbarControlHeight; radius: 8
                            text: "重启终端"; iconName: "restart_alt"; glyphSize: 14; contentSpacing: 3
                            tonal: true; foregroundColor: Theme.consoleText; labelFontSize: Theme.fontCaption; labelFontWeight: Font.Normal
                            border.width: 0; color: hovered ? "#3A4657" : "#343C48"
                            onClicked: root.controller.restart()
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
                        onTerminalTitleChanged: function(tabId, title) { root.controller.updateTerminalTitle(tabId, title) }
                        onContextMenuRequested: function(x, y) { terminalContextMenu.popup(x, y) }
                    }

                    DropArea {
                        id: terminalPathDropArea
                        anchors.fill: terminalView
                        z: 2
                        onEntered: function(drag) {
                            drag.accepted = drag.hasUrls
                                && root.controller.formatDroppedPaths(drag.urls).length > 0
                        }
                        onDropped: function(drop) {
                            if (!drop.hasUrls)
                                return
                            var text = root.controller.formatDroppedPaths(drop.urls)
                            if (!text.length)
                                return
                            terminalView.pasteText(text)
                            drop.accepted = true
                            terminalView.forceActiveFocus()
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: terminalPathDropArea.containsDrag
                            radius: Theme.radiusSmall
                            color: "#331B78F2"
                            border.color: Theme.primary
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "释放以插入路径"
                                color: Theme.consoleText
                                font.pixelSize: Theme.fontButton
                                font.weight: Font.DemiBold
                            }
                        }
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
                        AppMenuItem { text: "全选"; onTriggered: terminalView.selectAll() }
                        AppMenuItem { text: "清屏"; onTriggered: root.clearTerminal() }
                        AppMenuItem { text: "停止当前命令"; destructive: true; enabled: root.controller.running; onTriggered: root.controller.interrupt() }
                    }
                }
            }
        }
    }

    AppMenu {
        id: terminalTabContextMenu
        property string tabId: ""
        AppMenuItem { text: "重命名"; onTriggered: root.beginRename(terminalTabContextMenu.tabId) }
        AppMenuItem {
            text: "恢复自动标题"
            enabled: {
                var index = root.tabIndex(terminalTabContextMenu.tabId)
                return index >= 0 && root.controller.terminalTabs[index].hasCustomTitle
            }
            onTriggered: root.controller.resetTerminalTabTitle(terminalTabContextMenu.tabId)
        }
        AppMenuSeparator {}
        AppMenuItem { text: "关闭"; onTriggered: root.controller.closeTerminalTab(terminalTabContextMenu.tabId) }
        AppMenuItem {
            text: "关闭其他标签"
            enabled: root.controller.terminalTabs.length > 1
            onTriggered: root.controller.closeOtherTerminalTabs(terminalTabContextMenu.tabId)
        }
        AppMenuItem {
            text: "关闭右侧标签"
            enabled: {
                var index = root.tabIndex(terminalTabContextMenu.tabId)
                return index >= 0 && index < root.controller.terminalTabs.length - 1
            }
            onTriggered: root.controller.closeTerminalTabsToRight(terminalTabContextMenu.tabId)
        }
    }
}
