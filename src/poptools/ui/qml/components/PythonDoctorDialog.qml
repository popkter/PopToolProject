import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    required property var parentWindow
    property string message: ""
    property string packageNames: ""
    property string installStatus: ""
    property bool installing: false

    width: Math.min(540, parentWindow.width - 32)
    height: Math.min(460, parentWindow.height - 32)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 0
    closePolicy: root.installing ? Popup.NoAutoClose : Popup.CloseOnEscape

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
            Layout.preferredHeight: 68
            radius: 22
            color: Theme.surfaceContainerLow

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12
                MaterialIcon { icon: "fact_check"; iconSize: 26; color: Theme.primary }
                Text {
                    Layout.fillWidth: true
                    text: "检查 Python 依赖"
                    color: Theme.textPrimary
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 18
            spacing: 9

            Text {
                Layout.fillWidth: true
                text: root.message
                color: Theme.textPrimary
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Python 环境目录"
                color: Theme.textSecondary
                font.pixelSize: 12
            }

            TextField {
                Layout.fillWidth: true
                readOnly: true
                text: root.controller.pythonEnvironmentDirectory
                color: Theme.textPrimary
                font.family: "Cascadia Mono"
                font.pixelSize: 12
                selectByMouse: true
                implicitHeight: 38
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.packageNames.length > 0
                text: "待安装依赖"
                color: Theme.textSecondary
                font.pixelSize: 12
            }

            TextArea {
                Layout.fillWidth: true
                visible: root.packageNames.length > 0
                Layout.preferredHeight: 66
                readOnly: true
                text: root.packageNames
                color: Theme.textPrimary
                font.family: "Cascadia Mono"
                font.pixelSize: 12
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.packageNames.length > 0
                text: "确认后开始安装，安装完成前此窗口不会关闭。"
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.installStatus.length > 0
                text: root.installStatus
                color: root.installStatus.indexOf("失败") >= 0
                       ? Theme.errorColor : Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 22
            color: Theme.surface

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.outlineVariant
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 10
                Item { Layout.fillWidth: true }
                PrimaryButton {
                    implicitWidth: 104
                    implicitHeight: 48
                    text: "取消"
                    iconName: ""
                    tonal: true
                    enabled: !root.installing
                    onClicked: root.close()
                }
                PrimaryButton {
                    visible: root.packageNames.length > 0
                    implicitWidth: 126
                    implicitHeight: 48
                    text: root.installing ? "安装中…" : "确认安装"
                    iconName: root.installing ? "hourglass_top" : "download"
                    enabled: !root.installing
                    onClicked: {
                        root.installing = root.controller.installPythonDependencies(root.packageNames)
                    }
                }
            }
        }
    }
}
