import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Column {
    id: root
    objectName: "toolDeviceSelector"
    required property var controller
    required property string toolId
    property bool requiredDevice: false
    property bool explicitTarget: false
    property int stateRevision: 0
    readonly property var deviceState: {
        const revision = stateRevision
        return visible && controller && toolId.length > 0
            ? controller.deviceForTool(toolId)
            : ({ serial: "", available: false, label: "未检测到 Android 设备" })
    }
    spacing: 6
    Connections {
        target: root.controller
        function onStateChanged() { root.stateRevision += 1 }
    }
    onToolIdChanged: devicePopup.close()
    onVisibleChanged: { if (!visible) devicePopup.close() }

    function positionDeviceMenu() {
        const point = selector.mapToItem(Overlay.overlay, 0, selector.height)
        devicePopup.x = Math.max(8, Math.min(point.x,
                              Overlay.overlay.width - devicePopup.width - 8))
        devicePopup.y = point.y + 6 + devicePopup.height <= Overlay.overlay.height - 8
            ? point.y + 6 : Math.max(8, point.y - selector.height - devicePopup.height - 6)
    }
    function openDeviceMenu() {
        if (!root.controller || !root.toolId) return
        root.controller.refreshAndroidDevices()
        if (root.deviceState.pluginMissing) return
        positionDeviceMenu()
        devicePopup.open()
        Qt.callLater(positionDeviceMenu)
    }

    Text {
        text: "目标设备" + (root.requiredDevice ? " *" : "")
        color: Theme.textPrimary
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }
    Rectangle {
        id: selector
        width: parent.width
        height: 41
        radius: Theme.radiusConsole
        color: selectorMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
        border.color: Theme.outlineVariant
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 10
            spacing: 10
            MaterialIcon {
                icon: "smartphone"; iconSize: 19
                color: root.deviceState.available ? Theme.success : Theme.textSecondary
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.deviceState.label
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSupporting
                elide: Text.ElideMiddle
            }
            Text {
                text: root.deviceState.available ? "已连接"
                    : root.deviceState.serial ? "不可用" : "未选择"
                color: root.deviceState.available ? Theme.success : Theme.textSecondary
                font.pixelSize: Theme.fontSmall
            }
            MaterialIcon {
                icon: devicePopup.opened ? "expand_less" : "expand_more"
                iconSize: 18; color: Theme.textSecondary
            }
        }
        MouseArea {
            id: selectorMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openDeviceMenu()
        }
    }
    Text {
        width: parent.width
        visible: root.explicitTarget || (root.requiredDevice && !root.deviceState.available)
        text: root.explicitTarget
            ? "脚本已指定目标，界面选择仅作用于未指定目标的调用。"
            : root.deviceState.serial ? "原设备不可用，请重新连接或选择其他设备。"
            : "运行前请选择已连接的 Android 设备。"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.WordWrap
    }

    Popup {
        id: devicePopup
        objectName: "toolDevicePopup"
        parent: Overlay.overlay
        width: Math.min(root.width, Overlay.overlay ? Overlay.overlay.width - 16 : root.width)
        padding: Theme.space8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: AppPopupSurface { }
        onHeightChanged: { if (opened) root.positionDeviceMenu() }
        contentItem: ColumnLayout {
            spacing: Theme.space8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "选择 Android 设备"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontCaption
                }
                PrimaryButton {
                    text: "刷新设备"
                    iconName: "refresh"
                    compact: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    enabled: root.controller && !root.controller.androidDeviceRefreshing
                    iconSpinning: root.controller && root.controller.androidDeviceRefreshing
                    onClicked: root.controller.refreshAndroidDevices()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: deviceList.count === 0
                text: root.controller && root.controller.androidDeviceRefreshing
                    ? "正在查找设备…" : "未检测到已连接设备，请检查连接和 USB 调试授权。"
                wrapMode: Text.WordWrap
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSupporting
            }
            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count, 4) * 48
                clip: true
                model: root.controller ? root.controller.androidDevices : []
                ScrollBar.vertical: ScrollBar { }
                delegate: Rectangle {
                    required property var modelData
                    objectName: "deviceRow_" + modelData.serial
                    width: deviceList.width
                    height: 48
                    radius: Theme.radiusControl
                    color: modelData.serial === root.deviceState.serial
                        ? Theme.primaryContainer
                        : rowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: modelData.label
                            elide: Text.ElideMiddle
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSupporting
                        }
                        MaterialIcon {
                            visible: modelData.serial === root.deviceState.serial
                            icon: "check_circle"; iconSize: 20; color: Theme.primary
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controller.selectDeviceForTool(root.toolId, modelData.serial)
                            devicePopup.close()
                        }
                    }
                }
            }
        }
    }
}
