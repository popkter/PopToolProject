import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root
    required property var controller
    required property var androidController
    property string statusMessage: ""
    property bool statusError: false
    spacing: 18

    function openSaveDialog() {
        root.controller.chooseRecordingDirectory()
    }

    Connections {
        target: root.controller
        function onRecordingError(message) {
            root.statusMessage = message
            root.statusError = true
        }
        function onRecordingSaved(folder) {
            root.statusMessage = "已保存到：" + folder
            root.statusError = false
        }
    }

    Item { Layout.fillHeight: true }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        radius: Theme.radiusLarge
        color: Theme.surfaceContainerLow
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: root.controller.recording ? "radio_button_checked" : "videocam"
                iconSize: 54
                color: root.controller.recording ? Theme.errorColor : Theme.primary
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.controller.recording
                    ? "正在录制画面、系统声音、麦克风并截取日志…"
                    : "录制设备画面、系统声音和麦克风，同时保存 logcat 日志"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontComponentTitle
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.androidController.selectedAndroidDeviceLabel
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSupporting
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.controller.recording
              ? "点击右上角“结束录制”，选择目录后自动生成时间戳文件夹"
              : "需要 Android 11+；设备须支持 VOICE_PERFORMANCE 音源。部分应用禁止采集内部音频"
        color: Theme.textSecondary
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
    Text {
        Layout.fillWidth: true
        visible: root.statusMessage.length > 0
        text: root.statusMessage
        color: root.statusError ? Theme.errorColor : Theme.success
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
    Item { Layout.fillHeight: true }
}
