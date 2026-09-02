pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PopTools.Terminal 1.0
import "../theme"

Item {
    id: root
    required property var controller

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
        anchors.margins: 20
        spacing: 14

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
                    spacing: 7
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
            spacing: 8

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
                    spacing: 6

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
                                anchors.leftMargin: 12
                                anchors.rightMargin: 7
                                spacing: 6

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
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
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
                anchors.margins: Math.max(
                    6,
                    Math.ceil(Theme.radiusLarge * 0.3)
                )
                sessionId: root.controller.activeTerminalTabId
                fontSize: 14
                focus: true
                Accessible.role: Accessible.EditableText
                Accessible.name: "开发者终端"
                Accessible.description: "可交互命令行终端；使用 Ctrl+Shift+C 复制，Ctrl+Shift+V 粘贴"

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
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
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
                MenuItem {
                    text: "复制"
                    enabled: terminalView.hasSelection
                    onTriggered: terminalView.copySelection()
                }
                MenuItem {
                    text: "粘贴"
                    onTriggered: terminalView.pasteClipboard()
                }
                MenuSeparator {}
                MenuItem {
                    text: "全选"
                    onTriggered: terminalView.selectAll()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "PSReadLine 历史预测 · Tab 补全 · ↑↓ 历史命令 · Ctrl+R 搜索 · Ctrl+L 清屏"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
            }
            Button {
                text: "清屏"
                flat: true
                onClicked: {
                    root.controller.clear()
                    terminalView.forceActiveFocus()
                }
            }
            Button {
                text: "重启会话"
                flat: true
                onClicked: root.controller.restart()
            }
        }
    }
}
