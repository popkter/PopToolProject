import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

AppDialog {
    id: root
    required property var controller
    required property var parentWindow
    property var pendingValues: ({})
    width: Math.min(520, parentWindow.width - 24)
    height: Math.min(360, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    function openForRun(values) {
        pendingValues = Object.assign({}, values)
        open()
    }

    contentItem: ColumnLayout {
        spacing: Theme.space16
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space16
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.radiusMedium
                color: Theme.primaryContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "play_circle"
                    iconSize: 26
                    color: Theme.primary
                }
            }
            Text {
                Layout.fillWidth: true
                text: "运行“" + (root.controller.selectedTool.title || "当前脚本") + "”？"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSectionTitle
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
        }
        Text {
            Layout.fillWidth: true
            text: "该操作会按当前参数执行脚本。运行前请确认目标设备与输入内容。"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Theme.radiusMedium
            color: Theme.surfaceContainer
            border.color: Theme.outlineVariant
            border.width: 1
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space12
                Text {
                    text: "执行脚本"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    Layout.fillWidth: true
                    text: root.controller.selectedTool.title || "当前脚本"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSupporting
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                implicitWidth: 110; implicitHeight: 48
                text: "取消"; iconName: "close"; tonal: true
                onClicked: root.close()
            }
            PrimaryButton {
                implicitWidth: 120; implicitHeight: 48
                text: "继续运行"; iconName: "play_arrow"
                onClicked: {
                    root.close()
                    root.controller.runSelected(root.pendingValues)
                }
            }
        }
    }
}
