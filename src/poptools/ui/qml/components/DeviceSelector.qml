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
    readonly property real popupRowsHeight: popupDeviceCount * 58
                                            + Math.max(0, popupDeviceCount - 1) * 4

    implicitHeight: dense ? 52 : 58
    radius: Theme.radiusMedium
    color: selectorMouse.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow
    border.color: Theme.outlineVariant
    border.width: 1

    function openDeviceMenu() {
        var point = root.mapToItem(Overlay.overlay, 0, 0)
        devicePopup.x = Math.max(12, Math.min(point.x, Overlay.overlay.width - devicePopup.width - 12))
        devicePopup.y = Math.max(12, point.y - devicePopup.height - root.popupGap)
        devicePopup.open()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 8 : 13
        anchors.rightMargin: root.compact ? 8 : 10
        spacing: root.compact ? 0 : 10

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
            spacing: 1
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "全局 Android 设备"
                color: Theme.textSecondary
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.controller.selectedAndroidDeviceLabel
                color: Theme.textPrimary
                font.pixelSize: 12
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
        height: Math.min(devicePopup.contentItem.implicitHeight, Overlay.overlay.height - 24)
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: AppPopupSurface { }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.popupIconOnly ? 52 : 64
                Layout.leftMargin: root.popupIconOnly ? 6 : 18
                Layout.rightMargin: root.popupIconOnly ? 6 : 12
                spacing: root.popupIconOnly ? 0 : 10
                MaterialIcon { visible: !root.popupIconOnly; Layout.preferredWidth: 40; icon: "devices"; iconSize: 25; color: Theme.primary }
                ColumnLayout {
                    visible: !root.popupIconOnly
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: "选择 Android 设备"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                Item { visible: root.popupIconOnly; Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: refreshMouse.containsMouse ? Theme.primaryContainer : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "refresh"
                        iconSize: 22
                        color: Theme.primary
                        rotation: root.controller.androidDeviceRefreshing ? 120 : 0
                        Behavior on rotation { NumberAnimation { duration: 180 } }
                    }
                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        enabled: !root.controller.androidDeviceRefreshing
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.controller.refreshAndroidDevices()
                    }
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
                    spacing: 10
                    MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "phonelink_off"; iconSize: 34; color: Theme.textSecondary }
                    Text { visible: !root.popupIconOnly; text: root.controller.androidDeviceRefreshing ? "正在查找设备…" : "未检测到已连接设备"; color: Theme.textSecondary; font.pixelSize: 13 }
                }
            }

            ListView {
                id: deviceList
                visible: root.controller.androidDevices.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: root.popupRowsHeight
                Layout.margins: root.popupIconOnly ? 6 : 8
                clip: true
                spacing: 4
                model: root.controller.androidDevices
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    width: deviceList.width
                    height: 58
                    radius: Theme.radiusMedium
                    color: modelData.serial === root.controller.selectedAndroidDevice
                           ? Theme.primaryContainer
                           : (rowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    RowLayout {
                        visible: !root.popupIconOnly
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        spacing: 11
                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Rectangle {
                                anchors.centerIn: parent
                                width: 9
                                height: 9
                                radius: 5
                                color: Theme.success
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: deviceRow.modelData.label
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                Layout.fillWidth: true
                                text: deviceRow.modelData.status
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 10
                                color: Theme.success
                            }
                        }
                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: deviceRow.modelData.serial === root.controller.selectedAndroidDevice
                                icon: "check_circle"
                                iconSize: 22
                                color: Theme.primary
                            }
                        }
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: root.popupIconOnly
                        icon: deviceRow.modelData.serial === root.controller.selectedAndroidDevice
                              ? "phonelink_ring" : "smartphone"
                        iconSize: 27
                        color: deviceRow.modelData.serial === root.controller.selectedAndroidDevice
                               ? Theme.primary : Theme.success
                    }
                    property bool revealClickedName: false
                    ToolTip.visible: root.popupIconOnly
                                     && (rowMouse.containsMouse || deviceRow.revealClickedName)
                    ToolTip.text: deviceRow.modelData.label + "\n" + deviceRow.modelData.status
                    ToolTip.delay: rowMouse.containsMouse ? 300 : 0
                    ToolTip.timeout: 1800
                    Timer {
                        id: clickedNameTimer
                        interval: 1500
                        onTriggered: {
                            deviceRow.revealClickedName = false
                            devicePopup.close()
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
onClicked: {
                            root.controller.selectAndroidDevice(deviceRow.modelData.serial)
                            if (root.popupIconOnly) {
                                deviceRow.revealClickedName = true
                                clickedNameTimer.restart()
                            } else {
                                devicePopup.close()
                            }
                        }
                    }
                }
            }

        }
    }
}
