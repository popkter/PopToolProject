import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    clip: true
    required property var controller
    property bool compact: false
    property bool dense: false
    readonly property int popupGap: 8
    readonly property int popupDeviceCount: Math.min(3, root.controller.androidDevices.length)
    readonly property bool popupIconOnly: root.compact || devicePopup.width < 220
    readonly property int popupRowHeight: 52
    readonly property real popupRowsHeight: popupDeviceCount * popupRowHeight
                                            + Math.max(0, popupDeviceCount - 1) * 4

    implicitHeight: dense ? 60 : 74
    radius: Theme.radiusMedium
    color: selectorMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
    border.color: Theme.outlineVariant
    border.width: 1

    function positionDeviceMenu() {
        var point = root.mapToItem(Overlay.overlay, 0, 0)
        devicePopup.x = Math.max(12, Math.min(point.x, Overlay.overlay.width - devicePopup.width - 12))
        devicePopup.y = Math.max(12, point.y - devicePopup.height - root.popupGap)
    }

    function openDeviceMenu() {
        root.positionDeviceMenu()
        devicePopup.open()
        // The popup content is laid out lazily the first time it is opened. Reposition
        // after that layout pass so the final height is used instead of overlapping
        // the selector with the initial, incomplete height.
        Qt.callLater(root.positionDeviceMenu)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? Theme.space8 : Theme.space12
        anchors.rightMargin: root.compact ? Theme.space8 : Theme.space12
        spacing: root.compact ? Theme.space0 : Theme.space12

        Item { visible: root.compact; Layout.fillWidth: true }
        MaterialIcon {
            icon: "android"
            iconSize: 25
            color: root.controller.selectedAndroidDevice.length > 0 ? Theme.success : Theme.textSecondary
            Layout.preferredWidth: 28
        }
        ColumnLayout {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Theme.space4
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "全局 Android 设备"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontMicro
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.controller.selectedAndroidDeviceLabel
                color: Theme.textPrimary
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }
        }
        MaterialIcon {
            visible: !root.compact
            icon: devicePopup.opened ? "expand_less" : "expand_more"
            iconSize: 21
            color: Theme.textSecondary
        }
        Item { visible: root.compact; Layout.fillWidth: true }
    }

    ToolTip.visible: root.compact && selectorMouse.containsMouse
    ToolTip.text: root.controller.selectedAndroidDeviceLabel
    ToolTip.delay: 400

    MouseArea {
        id: selectorMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDeviceMenu()
    }

    Popup {
        id: devicePopup
        parent: Overlay.overlay
        width: root.width
        height: Math.min(devicePopup.contentItem.implicitHeight,
            Overlay.overlay.height - Theme.space24)
        padding: Theme.space0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: AppPopupSurface { }

        onOpened: root.positionDeviceMenu()
        onHeightChanged: {
            if (opened)
                root.positionDeviceMenu()
        }

        contentItem: ColumnLayout {
            spacing: Theme.space0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.popupIconOnly ? 52 : 64
                Layout.leftMargin: root.popupIconOnly
                    ? Theme.space8 : Theme.space20
                Layout.rightMargin: root.popupIconOnly
                    ? Theme.space8 : Theme.space12
                spacing: root.popupIconOnly ? Theme.space0 : Theme.space12
                MaterialIcon { visible: !root.popupIconOnly; Layout.preferredWidth: 40; icon: "devices"; iconSize: 25; color: Theme.primary }
                ColumnLayout {
                    visible: !root.popupIconOnly
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    Text {
                        Layout.fillWidth: true
                        text: "选择 Android 设备"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                Item { visible: root.popupIconOnly; Layout.fillWidth: true }
                PrimaryButton {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    compact: true
                    text: "刷新设备"
                    iconName: "refresh"
                    glyphSize: 22
                    tonal: true
                    foregroundColor: Theme.primary
                    border.width: 0
                    radius: Theme.radiusLarge
                    color: hovered ? Theme.primaryContainer : "transparent"
                    enabled: !root.controller.androidDeviceRefreshing
                    disabledOpacity: 0.38
                    iconSpinning: root.controller.androidDeviceRefreshing
                    onClicked: root.controller.refreshAndroidDevices()
                }
                Item { visible: root.popupIconOnly; Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outlineVariant }

            Item {
                id: emptyState
                visible: root.popupDeviceCount === 0
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                implicitHeight: emptyColumn.implicitHeight + 28
                Column {
                    id: emptyColumn
                    anchors.centerIn: parent
                    spacing: Theme.space12
                    MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "phonelink_off"; iconSize: 34; color: Theme.textSecondary }
                    Text { visible: !root.popupIconOnly; text: root.controller.androidDeviceRefreshing ? "正在查找设备…" : "未检测到已连接设备"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
                }
            }

            ListView {
                id: deviceList
                visible: root.controller.androidDevices.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: root.popupRowsHeight
                Layout.margins: Theme.space8
                clip: true
                spacing: Theme.space4
                model: root.controller.androidDevices
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    width: deviceList.width
                    height: root.popupRowHeight
                    radius: Theme.radiusMedium
                    color: modelData.serial === root.controller.selectedAndroidDevice
                           ? Theme.primaryContainer
                           : (rowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space12
                        anchors.rightMargin: Theme.space12
                        spacing: Theme.space8
                        MaterialIcon {
                            Layout.preferredWidth: 24
                            icon: "android"
                            iconSize: 23
                            color: Theme.success
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: deviceRow.modelData.serial
                            elide: Text.ElideMiddle
                            font.pixelSize: Theme.fontSupporting
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        MaterialIcon {
                            Layout.preferredWidth: 22
                            visible: deviceRow.modelData.serial === root.controller.selectedAndroidDevice
                            icon: "check_circle"
                            iconSize: 22
                            color: Theme.primary
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controller.selectAndroidDevice(deviceRow.modelData.serial)
                            devicePopup.close()
                        }
                    }
                }
            }

        }
    }
}
