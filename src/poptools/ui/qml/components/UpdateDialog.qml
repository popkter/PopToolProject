import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    required property var parentWindow

    width: Math.min(620, parentWindow.width - 24)
    height: Math.min(300, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 24
    closePolicy: controller.state === "downloading"
                 ? Popup.NoAutoClose : Popup.CloseOnEscape

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                color: Theme.primaryContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.controller.state === "downloaded" ? "download_done" : "system_update"
                    iconSize: 27
                    color: Theme.primaryText
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: root.controller.state === "downloading" ? "正在下载更新"
                          : root.controller.state === "downloaded" ? "更新已准备好"
                          : root.controller.state === "error" ? "更新遇到问题"
                          : "发现新版本"
                    color: Theme.textPrimary
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    visible: root.controller.availableVersion.length > 0
                    text: "当前 " + root.controller.currentVersion
                          + "  →  最新 " + root.controller.availableVersion
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
            Rectangle {
                visible: root.controller.state !== "downloading"
                         && root.controller.state !== "installing"
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: closeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "close"
                    iconSize: 22
                    color: Theme.textSecondary
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            visible: root.controller.state === "available"
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Theme.radiusMedium
            color: Theme.surfaceContainerLow
            border.color: Theme.outlineVariant
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.controller.releaseName
                    color: Theme.textPrimary
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    visible: root.controller.releasePageUrl.length > 0
                    text: "在 GitHub 查看完整发行说明"
                    color: Theme.primary
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(root.controller.releasePageUrl)
                    }
                }
            }
        }

        ColumnLayout {
            visible: root.controller.state === "downloading"
                     || root.controller.state === "downloaded"
                     || root.controller.state === "installing"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Item { Layout.fillHeight: true }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.controller.state === "downloaded" ? "check_circle" : "download"
                    iconSize: 44
                    color: root.controller.state === "downloaded" ? Theme.success : Theme.primary
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.controller.status
                color: Theme.textPrimary
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }
            ProgressBar {
                visible: root.controller.state === "downloading"
                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.controller.downloadProgress
                indeterminate: root.controller.totalSize.length === 0
                background: Rectangle {
                    implicitHeight: 10
                    radius: 5
                    color: Theme.surfaceContainerHigh
                }
                contentItem: Item {
                    implicitHeight: 10
                    Rectangle {
                        width: parent.width * root.controller.downloadProgress / 100
                        height: parent.height
                        radius: height / 2
                        color: Theme.primary
                    }
                }
            }
            Text {
                visible: root.controller.state === "downloading"
                         && root.controller.downloadedSize.length > 0
                Layout.fillWidth: true
                text: root.controller.totalSize.length > 0
                      ? root.controller.downloadedSize + " / " + root.controller.totalSize
                      : root.controller.downloadedSize
                color: Theme.textSecondary
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }
            Item { Layout.fillHeight: true }
        }

        Rectangle {
            visible: root.controller.state === "error"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.errorContainer
            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                MaterialIcon { icon: "error"; iconSize: 28; color: Theme.errorColor }
                Text {
                    Layout.fillWidth: true
                    text: root.controller.status
                    color: Theme.textPrimary
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Item { Layout.fillWidth: true }
            PrimaryButton {
                visible: root.controller.state === "available"
                implicitWidth: 112; implicitHeight: 48; radius: 24
                text: "下次提醒"; iconName: ""; tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                visible: root.controller.state === "available"
                implicitWidth: 128; implicitHeight: 48; radius: 24
                text: "跳过此版本"; iconName: ""; tonal: true
                onClicked: {
                    root.controller.skipVersion()
                    root.close()
                }
            }
            PrimaryButton {
                visible: root.controller.state === "available"
                implicitWidth: 122; implicitHeight: 48; radius: 24
                text: "立即更新"; iconName: "download"
                onClicked: root.controller.downloadUpdate()
            }
            PrimaryButton {
                visible: root.controller.state === "downloading"
                implicitWidth: 120; implicitHeight: 48; radius: 24
                text: "取消下载"; iconName: "close"; tonal: true
                onClicked: root.controller.cancelDownload()
            }
            PrimaryButton {
                visible: root.controller.state === "downloaded"
                implicitWidth: 116; implicitHeight: 48; radius: 24
                text: "稍后安装"; iconName: ""; tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                visible: root.controller.state === "downloaded"
                implicitWidth: 150; implicitHeight: 48; radius: 24
                text: "安装并重启"; iconName: "restart_alt"
                onClicked: root.controller.installAndRestart()
            }
            PrimaryButton {
                visible: root.controller.state === "error"
                implicitWidth: 104; implicitHeight: 48; radius: 24
                text: "关闭"; iconName: ""; tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                visible: root.controller.state === "error"
                implicitWidth: 112; implicitHeight: 48; radius: 24
                text: "重试"; iconName: "refresh"
                onClicked: root.controller.downloadUpdate()
            }
        }
    }
}
