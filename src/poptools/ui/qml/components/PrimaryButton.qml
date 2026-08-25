import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property string text: "运行"
    property string iconName: "play_arrow"
    property bool tonal: false
    property bool compact: false
    property bool successStyle: false
    readonly property color contentColor: !enabled ? Theme.textSecondary
                                          : successStyle ? Theme.successForeground
                                          : tonal ? Theme.primaryText : Theme.primaryForeground
    signal clicked()

    implicitHeight: 58
    implicitWidth: compact ? 58 : 180
    radius: Theme.radiusMedium
    color: !enabled ? Theme.surfaceContainerHigh
                    : successStyle ? (mouseArea.containsMouse ? Qt.darker(Theme.success, 1.08) : Theme.success)
                    : tonal ? (mouseArea.containsMouse ? Theme.primaryContainerHover : Theme.primaryContainer)
                            : (mouseArea.containsMouse ? Theme.primaryHover : Theme.primary)
    opacity: 1

    RowLayout {
        anchors.centerIn: parent
        spacing: root.compact ? 0 : 10
        MaterialIcon {
            visible: root.iconName.length > 0
            icon: root.iconName
            iconSize: 25
            color: root.contentColor
        }
        Text {
            visible: !root.compact
            text: root.text
            color: root.contentColor
            font.pixelSize: Theme.fontButton
            font.weight: Font.DemiBold
        }
    }

    ToolTip.visible: root.compact && mouseArea.containsMouse
    ToolTip.text: root.text
    ToolTip.delay: 450

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
