import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root

    required property var controller
    required property var parentWindow
    required property var parameterValues
    property bool scrcpySelected: false
    property bool overlaysVisible: false
    readonly property real parameterContentHeight: parameterFlow.height

    spacing: 16

    Rectangle {
        id: scrcpyHost
        visible: root.scrcpySelected
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 180
        radius: Theme.radiusLarge
        color: Theme.consoleBackground
        clip: true

        function syncGeometry() {
            const point = mapToItem(null, 0, 0)
            const canShow = visible && root.parentWindow.visible && !root.overlaysVisible
            root.controller.updateScrcpyGeometry(
                        Math.round(point.x), Math.round(point.y),
                        Math.round(width), Math.round(height), canShow)
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.controller.running ? "cast_connected" : "cast"
                iconSize: 54
                color: Theme.consoleMuted
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.controller.running
                      ? "正在连接设备并准备投屏…"
                      : "点击“开始投屏”，设备画面将在此处显示"
                color: Theme.consoleText
                font.pixelSize: 15
            }
        }

        Timer {
            interval: 100
            repeat: true
            running: scrcpyHost.visible
            onTriggered: scrcpyHost.syncGeometry()
        }
        onVisibleChanged: syncGeometry()
        Component.onCompleted: syncGeometry()
    }

    ScrollView {
        id: commandParameterScroll
        visible: !root.scrcpySelected
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Flow {
            id: parameterFlow
            width: commandParameterScroll.availableWidth
            height: childrenRect.height
            spacing: 13

            Repeater {
                model: root.controller.selectedTool.parameters || []
                delegate: Column {
                    required property var modelData
                    width: parameterFlow.width
                    spacing: 6

                    Text {
                        text: modelData.label + (modelData.required ? " *" : "")
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Loader {
                        id: parameterInputLoader
                        property int singleLineHeight: 54
                        width: parent.width
                        sourceComponent: modelData.kind === "multiline" ? multilineField
                                         : modelData.kind === "choice" ? choiceField
                                         : modelData.kind === "boolean" ? booleanField : normalField

                        Component {
                            id: normalField
                            TextField {
                                implicitHeight: parameterInputLoader.singleLineHeight
                                text: String(modelData.default || "")
                                placeholderText: modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: 15
                                leftPadding: 16
                                rightPadding: 16
                                echoMode: modelData.kind === "secret"
                                          ? TextInput.Password : TextInput.Normal
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[modelData.id] = text
                            }
                        }

                        Component {
                            id: multilineField
                            TextArea {
                                implicitHeight: Math.max(parameterInputLoader.singleLineHeight,
                                                         contentHeight + topPadding + bottomPadding)
                                text: String(modelData.default || "")
                                placeholderText: modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: 15
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 14
                                bottomPadding: 14
                                wrapMode: TextEdit.Wrap
                                background: Rectangle {
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                                    border.width: parent.activeFocus ? 2 : 1
                                }
                                onTextChanged: root.parameterValues[modelData.id] = text
                            }
                        }

                        Component {
                            id: choiceField
                            AppComboBox {
                                id: choiceControl
                                implicitHeight: parameterInputLoader.singleLineHeight
                                model: modelData.options || []
                                currentIndex: {
                                    const expected = String(modelData.default || "")
                                    for (let index = 0; index < count; index++) {
                                        if (String(choiceControl.textAt(index)) === expected)
                                            return index
                                    }
                                    return count > 0 ? 0 : -1
                                }
                                leftPadding: 16
                                rightPadding: 42
                                font.pixelSize: 15
                                onCurrentTextChanged: {
                                    if (currentIndex >= 0)
                                        root.parameterValues[modelData.id] = currentText
                                }
                            }
                        }

                        Component {
                            id: booleanField
                            Rectangle {
                                implicitHeight: parameterInputLoader.singleLineHeight
                                radius: Theme.radiusMedium
                                color: Theme.surface
                                border.color: Theme.outline
                                Switch {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    text: checked ? "已启用" : "未启用"
                                    checked: Boolean(modelData.default)
                                    onToggled: root.parameterValues[modelData.id] = checked
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
