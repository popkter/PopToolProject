import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root

    required property var toolController
    required property var utilities
    property bool compact: false
    property string jsonOutput: ""

    spacing: 14

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.toolController.selectedTool.executor.command === "timestamp" ? 1
                      : root.toolController.selectedTool.executor.command === "colors" ? 2 : 0

        RowLayout {
            spacing: root.compact ? 0 : 14

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        Layout.leftMargin: 18
                        Layout.rightMargin: 14
                        Text {
                            text: "输入 JSON"
                            color: Theme.textPrimary
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }
                    TextArea {
                        id: jsonInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 12
                        placeholderText: "粘贴需要解析的 JSON…"
                        text: "{\n  \"device\": \"Pixel 8\",\n  \"connected\": true\n}"
                        color: Theme.textPrimary
                        font.family: "Cascadia Mono"
                        font.pixelSize: 14
                        wrapMode: TextEdit.NoWrap
                        selectByMouse: true
                        background: Rectangle { radius: 12; color: Theme.surface }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        PrimaryButton {
                            Layout.fillWidth: true
                            text: "格式化"
                            iconName: "play_arrow"
                            onClicked: root.jsonOutput = root.utilities.formatJson(
                                jsonInput.text, false
                            )
                        }
                        PrimaryButton {
                            Layout.preferredWidth: 150
                            text: "压缩"
                            iconName: "compress"
                            tonal: true
                            onClicked: root.jsonOutput = root.utilities.formatJson(
                                jsonInput.text, true
                            )
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        Layout.leftMargin: 18
                        Layout.rightMargin: 14
                        Text {
                            text: "格式化结果"
                            color: Theme.textPrimary
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        PrimaryButton {
                            implicitWidth: 110
                            implicitHeight: 40
                            text: "复制"
                            iconName: "content_copy"
                            tonal: true
                            enabled: jsonOutputArea.text.length > 0
                            onClicked: {
                                jsonOutputArea.selectAll()
                                jsonOutputArea.copy()
                                jsonOutputArea.deselect()
                            }
                        }
                    }
                    TextArea {
                        id: jsonOutputArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 12
                        text: root.jsonOutput
                        placeholderText: "结果将显示在这里"
                        readOnly: true
                        selectByMouse: true
                        color: Theme.textPrimary
                        font.family: "Cascadia Mono"
                        font.pixelSize: 14
                        wrapMode: TextEdit.NoWrap
                        background: Rectangle { radius: 12; color: Theme.surface }
                    }
                }
            }
        }

        ColumnLayout {
            spacing: 16
            Item { Layout.fillHeight: true }
            Text {
                text: "输入时间戳或本地时间"
                color: Theme.textPrimary
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            TextField {
                id: timestampInput
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                placeholderText: "例如 1718000000 或 2026-07-29 14:30:00"
                color: Theme.textPrimary
                font.pixelSize: 16
                background: Rectangle {
                    radius: 14
                    color: Theme.surface
                    border.color: Theme.outline
                }
            }
            PrimaryButton {
                Layout.fillWidth: true
                text: "立即转换"
                iconName: "schedule"
                onClicked: timestampResult.text = root.utilities.convertTimestamp(
                    timestampInput.text
                )
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: Theme.radiusLarge
                color: Theme.primaryContainer
                Text {
                    id: timestampResult
                    anchors.fill: parent
                    anchors.margins: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "转换结果"
                    color: Theme.primaryText
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
            }
            Item { Layout.fillHeight: true }
        }

        InteractiveColorPicker {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
