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
    readonly property int parameterCount:
        (root.controller.selectedTool.parameters || []).length
    readonly property bool hasParameters: parameterCount > 0
    readonly property real parameterLabelHeight: 20
    readonly property real parameterInputHeight: 54
    readonly property real parameterLabelSpacing: 6
    readonly property real parameterItemSpacing: 13
    readonly property real parameterItemHeight:
        parameterLabelHeight + parameterLabelSpacing + parameterInputHeight
    readonly property real parameterContentHeight: parameterCount > 0
        ? parameterCount * parameterItemHeight
            + (parameterCount - 1) * parameterItemSpacing
        : 0

    spacing: 16

    Rectangle {
        id: scrcpyHost
        property bool geometryReady: false
        property int stableGeometryFrames: 0
        property string lastGeometryKey: ""
        visible: root.scrcpySelected
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 180
        radius: Theme.radiusLarge
        color: Theme.consoleBackground
        clip: true

        function geometrySnapshot() {
            const point = mapToItem(null, 0, 0)
            return {
                x: Math.round(point.x),
                y: Math.round(point.y),
                width: Math.round(width),
                height: Math.round(height)
            }
        }

        function hideUntilLayoutSettles() {
            geometryReady = false
            stableGeometryFrames = 0
            lastGeometryKey = ""
            root.controller.updateScrcpyGeometry(0, 0, 0, 0, false)
        }

        function syncGeometry() {
            const geometry = geometrySnapshot()
            const geometryKey = geometry.x + ":" + geometry.y + ":"
                              + geometry.width + ":" + geometry.height
            const validGeometry = geometry.width > 1 && geometry.height > 1

            if (!geometryReady) {
                if (validGeometry && geometryKey === lastGeometryKey)
                    stableGeometryFrames += 1
                else
                    stableGeometryFrames = 0
                lastGeometryKey = geometryKey
                geometryReady = validGeometry && stableGeometryFrames >= 2
            }

            const canShow = geometryReady && visible
                         && root.parentWindow.visible && !root.overlaysVisible
            root.controller.updateScrcpyGeometry(
                        geometry.x, geometry.y,
                        geometry.width, geometry.height, canShow)
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
                font.pixelSize: Theme.fontBody
            }
        }

        Timer {
            interval: scrcpyHost.geometryReady ? 100 : 16
            repeat: true
            running: scrcpyHost.visible
            onTriggered: scrcpyHost.syncGeometry()
        }
        onVisibleChanged: {
            if (visible)
                hideUntilLayoutSettles()
            else
                root.controller.updateScrcpyGeometry(0, 0, 0, 0, false)
        }
        Component.onCompleted: hideUntilLayoutSettles()
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
            height: root.parameterContentHeight
            spacing: root.parameterItemSpacing

            Repeater {
                model: root.controller.selectedTool.parameters || []
                delegate: Column {
                    required property var modelData
                    width: parameterFlow.width
                    height: root.parameterItemHeight
                    spacing: root.parameterLabelSpacing

                    Text {
                        width: parent.width
                        height: root.parameterLabelHeight
                        text: modelData.label + (modelData.required ? " *" : "")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontLabel
                        font.weight: Font.Medium
                    }

                    Loader {
                        id: parameterInputLoader
                        readonly property real singleLineHeight: root.parameterInputHeight
                        width: parent.width
                        height: singleLineHeight
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
                                font.pixelSize: Theme.fontBody
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
                                implicitHeight: parameterInputLoader.singleLineHeight
                                text: String(modelData.default || "")
                                placeholderText: modelData.placeholder || ""
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
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
                                font.pixelSize: Theme.fontBody
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
