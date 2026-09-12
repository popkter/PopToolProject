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
    readonly property int terminalToolbarControlHeight: 40
    readonly property real terminalTabMaximumWidth: 146
    readonly property real terminalTabMinimumWidth: 96
    readonly property real terminalTabMaximumFontSize: Theme.fontBody
    readonly property real terminalTabMinimumFontSize: 11
    readonly property real responsiveTerminalTabWidth: {
        var tabCount = Math.max(1, root.controller.terminalTabs.length)
        var addButtonWidth = 36
        var totalSpacing = terminalTabs.spacing * tabCount
        var fittedWidth = (terminalTabStrip.width - addButtonWidth - totalSpacing) / tabCount
        return Math.max(root.terminalTabMinimumWidth,
            Math.min(root.terminalTabMaximumWidth, fittedWidth))
    }
    readonly property real responsiveTerminalTabFontSize: {
        var widthRange = root.terminalTabMaximumWidth - root.terminalTabMinimumWidth
        var widthProgress = widthRange > 0
            ? (root.responsiveTerminalTabWidth - root.terminalTabMinimumWidth) / widthRange
            : 1
        return root.terminalTabMinimumFontSize
            + (root.terminalTabMaximumFontSize - root.terminalTabMinimumFontSize)
                * Math.max(0, Math.min(1, widthProgress))
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
            "default": Theme.consoleText.toString(),
            "command": Theme.consoleTag.toString(),
            "warning": Theme.consoleWarning.toString(),
            "string": Theme.success.toString(),
            "semantic": Theme.tertiaryText.toString(),
            "operator": Theme.teal.toString(),
            "error": Theme.consoleError.toString(),
            "muted": Theme.consoleMuted.toString()
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
            color: Theme.consoleBackground
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 0
                    color: Theme.consoleHeaderBackground

                    RowLayout {
                        z: 1
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

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
                                Row {
                                    id: terminalTabs
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Repeater {
                                        model: root.controller.terminalTabs
                                        delegate: Rectangle {
                                            id: tab
                                            required property int index
                                            required property var modelData
                                            width: root.responsiveTerminalTabWidth
                                            height: root.terminalToolbarControlHeight
                                            radius: 8
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
                                                    font.pixelSize: root.responsiveTerminalTabFontSize
                                                    elide: Text.ElideRight
                                                }
                                                TextField {
                                                    id: renameField
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 28
                                                    visible: root.renamingTabId === tab.modelData.tabId
                                                    color: Theme.consoleText
                                                    font.pixelSize: root.responsiveTerminalTabFontSize
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
                                                color: Theme.consoleMuted
                                                opacity: 0.45
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
                                x: Math.max(0, Math.min(
                                    terminalTabs.implicitWidth + terminalTabs.spacing,
                                    parent.width - width))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: root.terminalToolbarControlHeight
                                radius: 8
                                compact: true
                                text: "新增终端标签"
                                iconName: "add"
                                glyphSize: 20
                                tonal: true
                                foregroundColor: Theme.consoleText
                                border.width: 0
                                color: hovered ? "#3A4657" : "#313947"
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
                                    var angleDelta = wheel.angleDelta.y !== 0
                                        ? wheel.angleDelta.y : wheel.angleDelta.x
                                    root.scrollTerminalTabs(-angleDelta)
                                    wheel.accepted = true
                                }
                            }

                            MouseArea {
                                id: terminalWindowDragArea
                                objectName: "terminalWindowDragArea"
                                property point pressPosition: Qt.point(0, 0)
                                property bool systemMoveStarted: false
                                z: 2
                                x: Math.max(0, Math.min(parent.width,
                                    terminalTabAddButton.x + terminalTabAddButton.width
                                        + terminalTabs.spacing))
                                width: Math.max(0, parent.width - x)
                                height: parent.height
                                acceptedButtons: Qt.LeftButton
                                onPressed: function(mouse) {
                                    pressPosition = Qt.point(mouse.x, mouse.y)
                                    systemMoveStarted = false
                                    mouse.accepted = true
                                }
                                onPositionChanged: function(mouse) {
                                    if (!pressed || systemMoveStarted)
                                        return
                                    var distance = Math.abs(mouse.x - pressPosition.x)
                                        + Math.abs(mouse.y - pressPosition.y)
                                    if (distance < Application.styleHints.startDragDistance)
                                        return
                                    systemMoveStarted = true
                                    root.parentWindow.startSystemMove()
                                }
                                onReleased: systemMoveStarted = false
                                onCanceled: systemMoveStarted = false
                                onDoubleClicked: {
                                    if (root.parentWindow.visibility === Window.Maximized)
                                        root.parentWindow.showNormal()
                                    else
                                        root.parentWindow.showMaximized()
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: root.terminalToolbarControlHeight
                            visible: root.controller.terminalName === "PowerShell 7"
                            radius: 8
                            color: root.controller.powerShellHistoryListViewEnabled ? "#3A4657" : "#343C48"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    text: "历史"
                                    color: Theme.consoleText
                                    font.pixelSize: Theme.fontCaption
                                }
                                ToggleControl {
                                    id: historyToggle
                                    checked: root.controller.powerShellHistoryListViewEnabled
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.CheckBox
                                    Accessible.name: "显示 PowerShell 历史预测列表"
                                    Accessible.checked: checked
                                    onToggled: function(value) { root.setHistoryListViewEnabled(value) }
                                    Keys.onSpacePressed: function(event) {
                                        root.setHistoryListViewEnabled(!checked)
                                        event.accepted = true
                                    }
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
