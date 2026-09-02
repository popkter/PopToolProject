pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PopTools.Terminal 1.0
import "../theme"

Item {
    id: root
    required property var controller

    component TerminalContextMenuItem: MenuItem {
        id: menuItem
        property string shortcutText: ""
        property bool destructive: false

        implicitWidth: 252
        implicitHeight: 40
        leftPadding: Theme.space12
        rightPadding: Theme.space12

        contentItem: RowLayout {
            spacing: Theme.space20

            Text {
                Layout.fillWidth: true
                text: menuItem.text
                color: !menuItem.enabled
                       ? Theme.textSecondary
                       : (menuItem.destructive
                          ? Theme.errorColor : Theme.textPrimary)
                opacity: menuItem.enabled ? 1 : 0.5
                font.pixelSize: Theme.fontBody
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: menuItem.shortcutText
                color: menuItem.destructive && menuItem.enabled
                       ? Theme.errorColor : Theme.textSecondary
                opacity: menuItem.enabled ? 1 : 0.5
                font.pixelSize: Theme.fontCaption
                verticalAlignment: Text.AlignVCenter
            }
        }

        background: Rectangle {
            radius: Theme.radiusSmall
            color: menuItem.down
                   ? (menuItem.destructive
                      ? Theme.errorContainer : Theme.primaryContainer)
                   : (menuItem.highlighted
                      ? Theme.surfaceContainerHigh : "transparent")
            border.width: menuItem.activeFocus ? Theme.borderWidthThin : 0
            border.color: Theme.primary
        }
    }

    function copyTerminalSelection() {
        if (terminalView.hasSelection)
            terminalView.copySelection()
        terminalView.forceActiveFocus()
    }

    function copySelectionOrInterrupt() {
        if (terminalView.hasSelection)
            terminalView.copySelection()
        else
            root.controller.interrupt()
        terminalView.forceActiveFocus()
    }

    function cutTerminalSelection() {
        if (terminalView.hasSelection) {
            terminalView.copySelection()
            terminalView.clearSelection()
        }
        terminalView.forceActiveFocus()
    }

    function pasteTerminalClipboard() {
        terminalView.pasteClipboard()
        terminalView.forceActiveFocus()
    }

    function clearTerminal() {
        root.controller.clear()
        terminalView.forceActiveFocus()
    }

    function interruptTerminal() {
        root.controller.interrupt()
        terminalView.forceActiveFocus()
    }

    Shortcut {
        sequence: "Ctrl+Shift+C"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.copyTerminalSelection()
    }
    Shortcut {
        sequence: "Ctrl+Insert"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.copyTerminalSelection()
    }
    Shortcut {
        sequence: "Ctrl+Shift+V"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.pasteTerminalClipboard()
    }
    Shortcut {
        sequence: "Ctrl+V"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.pasteTerminalClipboard()
    }
    Shortcut {
        sequence: "Shift+Insert"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.pasteTerminalClipboard()
    }
    Shortcut {
        sequence: "Ctrl+Shift+X"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.cutTerminalSelection()
    }
    Shortcut {
        sequence: "Ctrl+X"
        context: Qt.WindowShortcut
        // Preserve Ctrl+X for terminal applications unless text is selected.
        enabled: root.visible && terminalView.hasSelection
        autoRepeat: false
        onActivated: root.cutTerminalSelection()
    }
    Shortcut {
        sequence: "Ctrl+L"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.clearTerminal()
    }
    Shortcut {
        sequence: "Ctrl+C"
        context: Qt.WindowShortcut
        enabled: root.visible
        autoRepeat: false
        onActivated: root.copySelectionOrInterrupt()
    }

    Component.onDestruction: root.controller.terminalDetached()

    Connections {
        target: root.controller
        function onTerminalData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalSnapshotData(tabId, data) { terminalView.feed(tabId, data) }
        function onTerminalResetRequested(tabId) { terminalView.resetSession(tabId) }
        function onTerminalSessionRemoved(tabId) { terminalView.removeSession(tabId) }
    }

    onVisibleChanged: {
        if (visible) {
            root.controller.ensureStarted()
            terminalView.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space12
        anchors.rightMargin: Theme.pagePadding
        anchors.topMargin: Theme.pagePadding
        anchors.bottomMargin: Theme.pagePadding
        spacing: Theme.sectionSpacing

        WorkspacePageHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            title: "终端"
            description: "原生 " + root.controller.terminalName
                + " 输入体验，python 与 pip 使用应用专属环境"
            actionWidth: 112

            Rectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 40
                radius: Theme.radiusLarge
                color: root.controller.running ? Theme.successContainer : Theme.errorContainer
                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.controlSpacing
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: Theme.radiusTiny
                        color: root.controller.running ? Theme.success : Theme.errorColor
                    }
                    Text {
                        text: root.controller.running ? "会话运行中" : "会话已停止"
                        color: root.controller.running ? Theme.success : Theme.errorColor
                        font.pixelSize: Theme.fontSupporting
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 42
            Layout.preferredHeight: 42
            Layout.maximumHeight: 42
            spacing: Theme.controlSpacing

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: terminalTabRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: terminalTabRow
                    height: parent.height
                    spacing: Theme.controlSpacing

                    Repeater {
                        model: root.controller.terminalTabs

                        delegate: Rectangle {
                            id: terminalTabDelegate
                            required property var modelData
                            width: 154
                            height: 38
                            radius: Theme.radiusSmall
                            color: terminalTabDelegate.modelData.active
                                   ? Theme.primaryContainer : Theme.surfaceContainerHigh
                            border.width: terminalTabDelegate.modelData.active ? 1 : 0
                            border.color: Theme.primary

                            RowLayout {
                                z: 1
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space12
                                anchors.rightMargin: Theme.space8
                                spacing: Theme.controlSpacing

                                Rectangle {
                                    Layout.preferredWidth: 7
                                    Layout.preferredHeight: 7
                                    radius: Theme.radiusTiny
                                    color: terminalTabDelegate.modelData.running
                                           ? Theme.success : Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: terminalTabDelegate.modelData.title
                                    color: terminalTabDelegate.modelData.active
                                           ? Theme.primary : Theme.textSecondary
                                    font.pixelSize: Theme.fontSupporting
                                    font.weight: terminalTabDelegate.modelData.active
                                                 ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                                MaterialIcon {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    visible: root.controller.terminalTabs.length > 1
                                    icon: "close"
                                    iconSize: 16
                                    color: closeTabMouse.containsMouse ? Theme.errorColor
                                                                        : Theme.textSecondary
                                    MouseArea {
                                        id: closeTabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: function(mouse) {
                                            mouse.accepted = true
                                            root.controller.closeTerminalTab(
                                                terminalTabDelegate.modelData.tabId)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 0
                                onClicked: root.controller.activateTerminalTab(
                                    terminalTabDelegate.modelData.tabId)
                            }
                        }
                    }

                    PrimaryButton {
                        width: 42
                        height: 38
                        radius: Theme.radiusSmall
                        compact: true
                        tonal: true
                        iconName: "add"
                        text: root.controller.canCreateTerminalTab
                              ? "新建终端标签" : "最多开启 7 个终端标签"
                        enabled: root.controller.canCreateTerminalTab
                        onClicked: root.controller.createTerminalTab()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Theme.radiusMedium
            color: Theme.tealContainer
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space12
                MaterialIcon {
                    icon: "terminal"
                    iconSize: 21
                    color: Theme.teal
                }
                Text {
                    Layout.fillWidth: true
                    text: root.controller.pythonExecutable
                    color: Theme.teal
                    font.family: "Cascadia Mono"
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideMiddle
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: "#141A20"
            clip: true

            TerminalView {
                id: terminalView
                anchors.fill: parent
                anchors.margins: Theme.terminalContentPadding
                sessionId: root.controller.activeTerminalTabId
                fontSize: 14
                focus: true
                Accessible.role: Accessible.EditableText
                Accessible.name: "开发者终端"
                Accessible.description: "可交互命令行终端；Ctrl+C 有选区时复制、无选区时停止当前命令，Ctrl+V 粘贴"

                Component.onCompleted: {
                    root.controller.terminalReady()
                    forceActiveFocus()
                }
                onInputGenerated: function(tabId, data) {
                    root.controller.writeInputToTab(tabId, data)
                }
                onTerminalSizeChanged: function(columns, rows) {
                    root.controller.resizeTerminal(columns, rows)
                }
                onContextMenuRequested: function(x, y) {
                    terminalContextMenu.popup(x, y)
                }
            }

            ScrollBar {
                id: terminalScrollBar
                anchors.top: terminalView.top
                anchors.right: terminalView.right
                anchors.bottom: terminalView.bottom
                orientation: Qt.Vertical
                policy: terminalView.scrollbackLineCount > 0
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                size: terminalView.rows / Math.max(
                    terminalView.rows,
                    terminalView.rows + terminalView.scrollbackLineCount)
                position: terminalView.scrollbackLineCount > 0
                    ? (terminalView.scrollbackLineCount - terminalView.scrollOffset)
                        / (terminalView.rows + terminalView.scrollbackLineCount)
                    : 0
                onPositionChanged: {
                    if (pressed)
                        terminalView.scrollOffset = terminalView.scrollbackLineCount
                            - Math.round(position
                                * (terminalView.rows + terminalView.scrollbackLineCount))
                }
            }

            Menu {
                id: terminalContextMenu
                objectName: "terminalContextMenu"
                width: 252
                topPadding: Theme.space8
                bottomPadding: Theme.space8
                leftPadding: Theme.space8
                rightPadding: Theme.space8
                background: AppPopupSurface {
                    cornerRadius: Theme.radiusLarge
                    fillColor: Theme.surfaceContainer
                    outlineColor: Theme.outlineVariant
                }
                onClosed: terminalView.forceActiveFocus()

                TerminalContextMenuItem {
                    text: "复制"
                    shortcutText: "Ctrl+C"
                    enabled: terminalView.hasSelection
                    onTriggered: root.copyTerminalSelection()
                }
                TerminalContextMenuItem {
                    text: "剪切"
                    shortcutText: "Ctrl+X"
                    enabled: terminalView.hasSelection
                    onTriggered: root.cutTerminalSelection()
                }
                TerminalContextMenuItem {
                    text: "粘贴"
                    shortcutText: "Ctrl+V"
                    onTriggered: root.pasteTerminalClipboard()
                }
                MenuSeparator {
                    topPadding: Theme.space4
                    bottomPadding: Theme.space4
                    leftPadding: Theme.space12
                    rightPadding: Theme.space12
                    contentItem: Rectangle {
                        implicitHeight: Theme.borderWidthThin
                        color: Theme.outlineVariant
                    }
                }
                TerminalContextMenuItem {
                    text: "全选"
                    onTriggered: terminalView.selectAll()
                }
                TerminalContextMenuItem {
                    text: "清屏"
                    shortcutText: "Ctrl+L"
                    onTriggered: root.clearTerminal()
                }
                TerminalContextMenuItem {
                    text: "停止当前命令"
                    shortcutText: "Ctrl+C"
                    destructive: true
                    enabled: root.controller.running
                    onTriggered: root.interruptTerminal()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: Theme.controlSpacing
            Text {
                Layout.fillWidth: true
                text: "Ctrl+C 复制/停止 · Ctrl+V 粘贴 · Ctrl+X 剪切 · Ctrl+L 清屏"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
            }
            Button {
                text: "清屏"
                flat: true
                onClicked: root.clearTerminal()
            }
            Button {
                text: "重启会话"
                flat: true
                onClicked: root.controller.restart()
            }
        }
    }
}
