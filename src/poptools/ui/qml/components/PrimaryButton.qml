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
    property bool iconSpinning: false
    readonly property color contentColor: !enabled ? Theme.textSecondary
                                          : successStyle ? Theme.successForeground
                                          : tonal ? Theme.primaryText : Theme.primaryForeground
    signal clicked()

    implicitHeight: 58
    implicitWidth: compact ? 58 : 180
    radius: Theme.radiusMedium
    color: !enabled ? (Theme.buttonDisabled || Theme.surfaceContainerHigh)
                    : successStyle ? (mouseArea.containsMouse ? Qt.darker(Theme.success, 1.08) : Theme.success)
                    : tonal ? (mouseArea.containsMouse ? Theme.primaryContainerHover : Theme.primaryContainer)
                            : (mouseArea.containsMouse ? Theme.primaryHover : Theme.primary)
    border.width: mouseArea.pressed ? 2 : 1
    border.color: !enabled ? Theme.outline
                    : mouseArea.pressed ? Theme.buttonShadow
                    : mouseArea.containsMouse ? Theme.primaryHover
                    : Theme.primary

    // XP-style highlight edge for 3D effect
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: mouseArea.pressed ? 0 : 1
        color: mouseArea.pressed ? "transparent" : (Theme.buttonHighlight || "#FFFFFF")
        visible: !root.tonal && !root.successStyle
        opacity: mouseArea.containsMouse ? 0.8 : 0.5
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: root.compact ? 0 : 10
        MaterialIcon {
            id: buttonIcon
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

    RotationAnimator {
        target: buttonIcon
        from: 0
        to: 360
        duration: 750
        loops: Animation.Infinite
        running: root.iconSpinning && buttonIcon.visible
        onRunningChanged: {
            if (!running)
                buttonIcon.rotation = 0
        }
    }

    AppToolTip {
        visible: root.compact && mouseArea.containsMouse
        text: root.text
        delay: 450
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
