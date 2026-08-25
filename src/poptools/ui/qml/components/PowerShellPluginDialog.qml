import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root

    required property var controller
    required property var parentWindow
    property bool cancelRequested: false

    width: Math.min(572, Overlay.overlay.width - 24)
    height: Math.min(410, Overlay.overlay.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: root.controller.pluginInstalling
                 ? Popup.NoAutoClose : Popup.CloseOnEscape

    function cancel() {
        if (!root.controller.pluginInstalling) {
            root.close()
            return
        }
        if (!root.cancelRequested
                && root.controller.cancelPowerShellPluginInstall())
            root.cancelRequested = true
    }

    onOpened: cancelRequested = false
    onClosed: cancelRequested = false

    Connections {
        target: root.controller

        function onPluginInstallFinished(success, message) {
            if (root.cancelRequested) {
                root.cancelRequested = false
                root.close()
            }
        }
    }

    background: Rectangle {
        radius: 22
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            color: Theme.surfaceContainerLow
            radius: 22

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                color: parent.color
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 15
                    color: Theme.primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "terminal"
                        iconSize: 28
                        color: Theme.primary
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "安装 PowerShell 7 插件"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontDialogTitle
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "为内置终端安装应用专用的 PowerShell 运行环境"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSupporting
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 21
                    color: closeMouse.containsMouse && closeMouse.enabled
                           ? Theme.surfaceContainerHigh : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        iconSize: 23
                        color: Theme.textSecondary
                        opacity: closeMouse.enabled ? 1 : 0.38
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        enabled: !root.controller.pluginInstalling
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.close()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.topMargin: 18
            Layout.bottomMargin: 16
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "终端需要应用专用的 PowerShell " + root.controller.pluginVersion
                    + "。是否下载并安装官方 PowerShell 7 插件？"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: "插件约 120 MB，仅安装到当前用户的应用数据目录，不修改系统 PowerShell。"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
                wrapMode: Text.WordWrap
            }
            Text {
                text: "安装目录"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption
            }
            TextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                readOnly: true
                text: root.controller.pluginDirectory
                selectByMouse: true
                color: Theme.textPrimary
                font.family: "Cascadia Mono"
                font.pixelSize: Theme.fontCaption
                leftPadding: 12
                rightPadding: 12
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surface
                    border.color: Theme.outline
                }
            }
            ProgressBar {
                Layout.fillWidth: true
                visible: root.controller.pluginInstalling
                from: 0
                to: 100
                value: root.controller.pluginInstallProgress
            }
            Text {
                Layout.fillWidth: true
                visible: root.controller.pluginInstallStatus.length > 0
                text: root.controller.pluginInstallStatus
                color: text.indexOf("失败") >= 0
                       ? Theme.errorColor : Theme.textSecondary
                font.pixelSize: Theme.fontCaption
                wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true }
        }

        Rectangle {
            id: dialogFooter
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 22
            color: Theme.surface

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outlineVariant
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 10

                Item { Layout.fillWidth: true }
                PrimaryButton {
                    implicitWidth: 112
                    implicitHeight: 48
                    text: root.controller.pluginInstalling ? "取消安装" : "取消"
                    iconName: ""
                    tonal: true
                    enabled: !root.cancelRequested
                    onClicked: root.cancel()
                }
                PrimaryButton {
                    implicitWidth: 142
                    implicitHeight: 48
                    text: root.controller.pluginInstalling ? "安装中…" : "确认安装"
                    iconName: root.controller.pluginInstalling
                              ? "hourglass_top" : "download"
                    enabled: !root.controller.pluginInstalling
                    onClicked: root.controller.installPowerShellPlugin()
                }
            }
        }
    }
}
