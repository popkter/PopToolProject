import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    required property var controller
    readonly property var options: [
        { "label": "按添加时间", "value": "added_time", "icon": "schedule" },
        { "label": "按名称", "value": "name", "icon": "sort_by_alpha" },
        { "label": "按使用频率", "value": "usage", "icon": "trending_up" },
        { "label": "自定义排序", "value": "custom", "icon": "drag_indicator" }
    ]

    implicitWidth: 40
    implicitHeight: 40
    radius: 20
    color: buttonMouse.containsMouse || sortPopup.opened
           ? Theme.primaryContainerHover : "transparent"

    function openMenu() {
        var point = root.mapToItem(Overlay.overlay, 0, root.height)
        sortPopup.x = Math.max(12, Math.min(point.x + root.width - sortPopup.width,
                                           Overlay.overlay.width - sortPopup.width - 12))
        sortPopup.y = Math.max(12, Math.min(point.y + 6,
                                           Overlay.overlay.height - sortPopup.height - 12))
        sortPopup.open()
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: "sort"
        iconSize: 24
        color: Theme.primary
    }

    ToolTip.visible: buttonMouse.containsMouse
    ToolTip.text: "排序：" + root.controller.toolSortModeLabel
    ToolTip.delay: 450

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openMenu()
    }

    Popup {
        id: sortPopup
        parent: Overlay.overlay
        width: 188
        height: contentColumn.implicitHeight + 16
        padding: 8
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: AppPopupSurface { }

        contentItem: ColumnLayout {
            id: contentColumn
            spacing: 3
            Repeater {
                model: root.options
                delegate: Rectangle {
                    id: optionRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.radiusMedium
                    color: modelData.value === root.controller.toolSortMode
                           ? Theme.primaryContainer
                           : (optionMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10
                        MaterialIcon {
                            icon: optionRow.modelData.icon
                            iconSize: 20
                            color: optionRow.modelData.value === root.controller.toolSortMode
                                   ? Theme.primary : Theme.textSecondary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: optionRow.modelData.label
                            color: Theme.textPrimary
                            font.pixelSize: 13
                        }
                        MaterialIcon {
                            visible: optionRow.modelData.value === root.controller.toolSortMode
                            icon: "check"
                            iconSize: 19
                            color: Theme.primary
                        }
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controller.setToolSortMode(optionRow.modelData.value)
                            sortPopup.close()
                        }
                    }
                }
            }
        }
    }
}
