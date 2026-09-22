pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import PopTools.Terminal 1.0
import "../theme"

Item {
    id: root
    required property var controller
    required property var parentWindow
    signal createScriptRequested(string command, string kind)
    readonly property int terminalToolbarControlHeight: 32
    readonly property real terminalTabMaximumWidth: Theme.terminalTabMaximumWidth
    readonly property real terminalTabMinimumWidth: Theme.terminalTabMinimumWidth
    readonly property real responsiveTerminalTabWidth: {
        var tabCount = Math.max(1, root.controller.terminalTabs.length)
        var addButtonWidth = terminalTabAddButton.width
        var totalSpacing = terminalTabs.spacing * tabCount
        var fittedWidth = (terminalTabStrip.width - addButtonWidth - totalSpacing) / tabCount
        return Math.max(root.terminalTabMinimumWidth,
            Math.min(root.terminalTabMaximumWidth, fittedWidth))
    }
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
    function ensureActiveTerminalTabVisible() {
        if (terminalTabFlick.width <= 0)
            return
        var maximumContentX = Math.max(0,
            terminalTabFlick.contentWidth - terminalTabFlick.width)
        if (maximumContentX <= 0) {
            terminalTabFlick.contentX = 0
            return
        }
        terminalTabFlick.contentX = Math.max(0,
            Math.min(maximumContentX, terminalTabFlick.contentX))
        var index = root.tabIndex(root.controller.activeTerminalTabId)
        if (index < 0)
            return
        var tabLeft = index * (root.responsiveTerminalTabWidth + terminalTabs.spacing)
        var tabRight = tabLeft + root.responsiveTerminalTabWidth
        var viewportLeft = terminalTabFlick.contentX
        var viewportRight = viewportLeft + terminalTabFlick.width
        if (tabLeft < viewportLeft)
            terminalTabFlick.contentX = Math.max(0, tabLeft)
        else if (tabRight > viewportRight)
            terminalTabFlick.contentX = Math.min(maximumContentX,
                tabRight - terminalTabFlick.width)
    }
    function scrollTerminalTabs(delta) {
        var maximumContentX = Math.max(0,
            terminalTabFlick.contentWidth - terminalTabFlick.width)
        terminalTabFlick.contentX = Math.max(0,
            Math.min(maximumContentX, terminalTabFlick.contentX + delta))
    }
    function syncTerminalSyntaxColors() {
        root.controller.configureTerminalSyntaxColors({
            "default": "#E5E7EB",
            "command": "#8CC8FF",
            "warning": "#FFD166",
            "string": "#9BE3B1",
            "semantic": "#D7B5FF",
            "operator": "#80DED9",
            "error": "#FF9B93",
            "muted": "#AAB4C3"
        })
    }
    function setHistoryListViewEnabled(value) {
        root.controller.setPowerShellHistoryListViewEnabled(value)
        terminalView.forceActiveFocus()
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
    onVisibleChanged: if (visible) {
        root.syncTerminalSyntaxColors()
        root.controller.ensureStarted()
        terminalView.forceActiveFocus()
    }

    Timer {
        id: terminalSyntaxColorSync
        interval: 0
        onTriggered: root.syncTerminalSyntaxColors()
    }

    Connections {
        target: Theme
        function onConsoleTextChanged() { terminalSyntaxColorSync.restart() }
        function onConsoleTagChanged() { terminalSyntaxColorSync.restart() }
        function onConsoleWarningChanged() { terminalSyntaxColorSync.restart() }
        function onConsoleErrorChanged() { terminalSyntaxColorSync.restart() }
        function onConsoleMutedChanged() { terminalSyntaxColorSync.restart() }
        function onSuccessChanged() { terminalSyntaxColorSync.restart() }
        function onTertiaryTextChanged() { terminalSyntaxColorSync.restart() }
        function onTealChanged() { terminalSyntaxColorSync.restart() }
    }

    Connections {
        target: root.controller
        function onTerminalData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalSnapshotData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalResetRequested(tabId) { terminalView.resetSession(tabId) }
        function onTerminalSessionRemoved(tabId) { terminalView.removeSession(tabId) }
        function onTerminalTabsChanged() {
            Qt.callLater(root.ensureActiveTerminalTabVisible)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 0
            color: Theme.terminalBackground
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.terminalToolbarHeight
                    radius: 0
                    color: Theme.terminalToolbar

                    RowLayout {
                        z: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        height: root.terminalToolbarControlHeight
                        anchors.leftMargin: Theme.space4
                        anchors.rightMargin: Theme.space8
                        spacing: 0

                        Item {
                            id: terminalTabStrip
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            onWidthChanged: Qt.callLater(root.ensureActiveTerminalTabVisible)

                            Flickable {
                                id: terminalTabFlick
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(0,
                                    terminalTabAddButton.x - terminalTabs.spacing)
                                contentWidth: terminalTabs.implicitWidth
                                contentHeight: height
                                clip: true
                                interactive: contentWidth > width
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                onWidthChanged: Qt.callLater(root.ensureActiveTerminalTabVisible)
                                onContentWidthChanged: Qt.callLater(root.ensureActiveTerminalTabVisible)
                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }
                                Row {
                                    id: terminalTabs
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.space8
                                    Repeater {
                                        model: root.controller.terminalTabs
                                        delegate: Rectangle {
                                            id: tab
                                            required property int index
                                            required property var modelData
                                            width: root.responsiveTerminalTabWidth
                                            height: 32
                                            radius: Theme.radiusControl
                                            color: modelData.active ? Theme.terminalBackground
                                                : tabHover.hovered
                                                  ? (Theme.terminalTabSelected)
                                                  : Theme.terminalTabSelected
                                            border.width: modelData.active ? 1 : 0
                                            border.color: Theme.terminalTabBorder
                                            HoverHandler { id: tabHover }
                                            RowLayout {
                                                z: 1
                                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: Theme.space8; spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    visible: root.renamingTabId !== tab.modelData.tabId
                                                    text: tab.modelData.title || "Android 调试"
                                                    color: tab.modelData.active
                                                        ? Theme.consoleText
                                                        : (Theme.terminalTabMuted)
                                                    font.pixelSize: Theme.fontSupporting
                                                    elide: Text.ElideRight
                                                }
                                                AppTextField {
                                                    id: renameField
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    Layout.preferredHeight: 28
                                                    visible: root.renamingTabId === tab.modelData.tabId
                                                    color: Theme.terminalTabText
                                                    font.pixelSize: Theme.fontSupporting
                                                    leftPadding: 6; rightPadding: 6; topPadding: 0; bottomPadding: 0
                                                    selectByMouse: true
                                                    background: Rectangle {
                                                        radius: Theme.radiusTiny
                                                        color: Theme.surfaceContainerLow
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
                                                    visible: true
                                                    opacity: tab.modelData.active || tabHover.hovered ? 1 : 0
                                                    enabled: opacity > 0
                                                    Layout.preferredWidth: 20
                                                    Layout.preferredHeight: 20
                                                    compact: true
                                                    text: "关闭终端标签"
                                                    iconName: "close"
                                                    glyphSize: 15
                                                    tonal: true
                                                    foregroundColor: Theme.terminalTabAction
                                                    color: hovered
                                                        ? (Theme.terminalTabHover)
                                                        : "transparent"
                                                    border.width: 0
                                                    radius: Theme.radiusTiny
                                                    onClicked: root.controller.closeTerminalTab(tab.modelData.tabId)
                                                }
                                            }
                                            MouseArea {
                                                id: tabHoverArea
                                                anchors.fill: parent
                                                z: 0
                                                hoverEnabled: true
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
                                                        terminalTabContextMenu.popup(tab, mouse.x, mouse.y)
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                z: 2
                                                anchors.right: parent.right
                                                anchors.rightMargin: -Math.floor(terminalTabs.spacing / 2)
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 1
                                                height: 20
                                                color: Theme.terminalTabDivider
                                                opacity: 1
                                                visible: !tab.modelData.active
                                                    && tab.index < root.controller.terminalTabs.length - 1
                                                    && !root.controller.terminalTabs[tab.index + 1].active
                                            }
                                        }
                                    }
                                }
                            }

                            PrimaryButton {
                                id: terminalTabAddButton
                                z: 4
                                x: Math.max(0, parent.width - width)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                radius: Theme.radiusSmall
                                compact: true
                                text: "新增终端标签 (Ctrl+T)"
                                iconName: "add"
                                glyphSize: 20
                                tonal: true
                                foregroundColor: Theme.navigationActiveIcon
                                border.width: 1
                                border.color: hovered ? (Theme.navigationActiveBorder)
                                    : (Theme.navigationBorder)
                                color: pressed ? Theme.primaryContainerHover
                                    : hovered ? Theme.primaryContainer : Theme.surfaceContainerLow
                                enabled: root.controller.canCreateTerminalTab
                                disabledOpacity: 1
                                onClicked: root.controller.createTerminalTab()
                            }

                            MouseArea {
                                z: 3
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: function(wheel) {
                                    if (!terminalTabFlick.interactive) {
                                        wheel.accepted = false
                                        return
                                    }
                                    var delta = wheel.pixelDelta.x !== 0
                                        ? wheel.pixelDelta.x : wheel.pixelDelta.y
                                    if (delta === 0)
                                        delta = wheel.angleDelta.x !== 0
                                            ? wheel.angleDelta.x : wheel.angleDelta.y
                                    root.scrollTerminalTabs(-delta)
                                    wheel.accepted = true
                                }
                            }

                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TerminalView {
                        id: terminalView
                        visible: root.controller.terminalTabs.length > 0
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space8
                        anchors.rightMargin: Theme.space8
                        anchors.topMargin: Theme.space8
                        anchors.bottomMargin: 10
                        sessionId: root.controller.activeTerminalTabId
                        fontSize: Theme.fontBody
                        focus: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "开发者终端"
                        Component.onCompleted: {
                            root.syncTerminalSyntaxColors()
                            root.controller.terminalReady()
                            forceActiveFocus()
                        }
                        onInputGenerated: function(tabId, data) { root.controller.writeInputToTab(tabId, data) }
                        onTerminalSizeChanged: function(columns, rows) { root.controller.resizeTerminal(columns, rows) }
                        onTerminalTitleChanged: function(tabId, title) { root.controller.updateTerminalTitle(tabId, title) }
                        onContextMenuRequested: function(x, y) { terminalContextMenu.popup(x, y) }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(360, parent.width - Theme.space32)
                        visible: root.controller.terminalTabs.length === 0
                        spacing: Theme.space16
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "terminal"; iconSize: 40; color: Theme.consoleMuted
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "没有打开的终端"
                            color: Theme.consoleText; font.pixelSize: Theme.fontSectionTitle
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "可以前往设置管理插件，或新建终端继续使用。"
                            color: Theme.consoleMuted; font.pixelSize: Theme.fontBody
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        }
                        PrimaryButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "新建终端"; iconName: "add"
                            onClicked: root.controller.createTerminalTab()
                        }
                    }

                    DropArea {
                        id: terminalPathDropArea
                        enabled: root.controller.terminalTabs.length > 0
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
                            color: Theme.terminalDropHighlight
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
                        AppMenuItem {
                            objectName: "addSelectionToCustomScript"
                            text: "添加到自定义脚本"
                            enabled: terminalView.hasSelection
                            onTriggered: {
                                var command = terminalView.selectionText()
                                if (command.trim().length > 0)
                                    root.createScriptRequested(command,
                                        Qt.platform.os === "windows" ? "powershell" : "bash")
                            }
                        }
                        AppMenuItem { text: "粘贴"; onTriggered: root.pasteClipboard() }
                        AppMenuItem { text: "全选"; onTriggered: terminalView.selectAll() }
                        AppMenuItem { text: "清屏"; onTriggered: root.clearTerminal() }
                        AppMenuItem { text: "重启终端"; onTriggered: root.controller.restart() }
                        AppMenuItem {
                            visible: root.controller.terminalName === "PowerShell 7"
                            text: root.controller.powerShellHistoryListViewEnabled
                                ? "关闭历史预测列表" : "显示历史预测列表"
                            onTriggered: root.setHistoryListViewEnabled(
                                !root.controller.powerShellHistoryListViewEnabled)
                        }
                        AppMenuItem { text: "停止当前命令"; destructive: true; enabled: root.controller.running; onTriggered: root.controller.interrupt() }
                        AppMenuItem {
                            text: "停止所有终端会话"
                            destructive: true
                            enabled: root.controller.terminalTabs.some(function(tab) { return tab.running })
                            onTriggered: root.controller.stop()
                        }
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
