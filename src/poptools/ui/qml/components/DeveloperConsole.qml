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
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "终端"
                    color: Theme.textPrimary
                    font.pixelSize: 30
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "原生 PowerShell 7 输入体验，python 与 pip 使用应用专属环境"
                    color: Theme.textSecondary
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 40
                radius: 20
                color: root.controller.running ? Theme.successContainer : Theme.errorContainer
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.controller.running ? Theme.success : Theme.errorColor
                    }
                    Text {
                        text: root.controller.running ? "会话运行中" : "会话已停止"
                        color: root.controller.running ? Theme.success : Theme.errorColor
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
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
                    font.pixelSize: 12
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
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "PSReadLine 历史预测 · Tab 补全 · ↑↓ 历史命令 · Ctrl+R 搜索 · Ctrl+L 清屏"
                color: Theme.textSecondary
                font.pixelSize: 12
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
