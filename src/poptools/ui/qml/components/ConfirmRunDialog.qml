import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    required property var controller
    required property var parentWindow
    property var pendingValues: ({})
    width: Math.min(520, parentWindow.width - 24)
    height: Math.min(300, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    background: Rectangle { radius: Theme.radiusLarge; color: Theme.surface }

    function openForRun(values) {
        pendingValues = Object.assign({}, values)
        open()
    }

    contentItem: ColumnLayout {
        spacing: 14
        MaterialIcon { icon: "warning"; iconSize: 34; color: Theme.primary }
        Text {
            text: "确认运行此功能？"
            color: Theme.textPrimary
            font.pixelSize: 23
            font.weight: Font.Bold
        }
        Text {
            Layout.fillWidth: true
            text: "此功能可能修改设备或本地文件。请确认当前设备与参数无误后继续。"
            color: Theme.textSecondary
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                implicitWidth: 110; implicitHeight: 48
                text: "取消"; iconName: ""; tonal: true
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
