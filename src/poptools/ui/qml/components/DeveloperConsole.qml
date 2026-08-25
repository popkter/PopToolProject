pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebChannel
import QtWebEngine
import "../theme"

Item {
    id: root
    required property var controller

    Component.onDestruction: root.controller.terminalDetached()

    QtObject {
        id: terminalBridge
        WebChannel.id: "terminalBridge"
        signal dataReceived(string data)
        signal snapshotReceived(string data)
        signal resetRequested()

        function writeInput(data) {
            root.controller.writeInput(data)
        }
        function resizeTerminal(columns, rows) {
            root.controller.resizeTerminal(columns, rows)
        }
        function terminalReady() {
            root.controller.terminalReady()
        }
    }

    WebChannel {
        id: terminalChannel
        registeredObjects: [terminalBridge]
    }

    Connections {
        target: root.controller
        function onTerminalData(data) { terminalBridge.dataReceived(data) }
        function onTerminalSnapshotData(data) { terminalBridge.snapshotReceived(data) }
        function onTerminalResetRequested() { terminalBridge.resetRequested() }
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
                radius: 20
                color: root.controller.running ? Theme.successContainer : Theme.errorContainer
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
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
                            radius: 10
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
                                    radius: 4
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
                        radius: 10
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

            WebEngineView {
                id: terminalView
                anchors.fill: parent
                anchors.margins: 6
                backgroundColor: "#141A20"
                webChannel: terminalChannel
                url: Qt.resolvedUrl("../../terminal/index.html")
                focus: true
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
