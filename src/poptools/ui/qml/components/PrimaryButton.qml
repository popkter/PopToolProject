import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property string text: "运行"
    property string iconName: "play_arrow"
    property bool tonal: false
    property bool compact: false
    property bool showHoverTips: compact
    property bool successStyle: false
    property bool dangerStyle: false
    property bool iconSpinning: false
    property color foregroundColor: "transparent"
    property real labelFontSize: Theme.fontButton
    property int labelFontWeight: Font.DemiBold
    property real glyphSize: 25
    property real contentSpacing: compact ? 0 : 10
    property real disabledOpacity: 1
    property bool contentFillWidth: false
    property real contentHorizontalPadding: 0
    property int labelElide: Text.ElideNone
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed
    readonly property color contentColor: foregroundColor.a > 0 ? foregroundColor
                                          : !enabled ? Theme.textSecondary
                                          : dangerStyle ? "white"
                                          : successStyle ? Theme.successForeground
                                          : tonal ? Theme.primaryText : Theme.primaryForeground
    signal clicked()

    implicitHeight: 58
    implicitWidth: compact ? 58 : 180
    opacity: enabled ? 1 : disabledOpacity
    radius: Theme.radiusMedium
    color: !enabled ? (Theme.buttonDisabled || Theme.surfaceContainerHigh)
                    : dangerStyle ? (mouseArea.containsMouse ? Qt.darker(Theme.errorColor, 1.08) : Theme.errorColor)
                    : successStyle ? (mouseArea.containsMouse ? Qt.darker(Theme.success, 1.08) : Theme.success)
                    : tonal ? (mouseArea.containsMouse ? Theme.primaryContainerHover : Theme.primaryContainer)
                            : (mouseArea.containsMouse ? Theme.primaryHover : Theme.primary)
    border.width: mouseArea.pressed ? 2 : 1
    border.color: !enabled ? Theme.outline
                    : mouseArea.pressed ? Theme.buttonShadow
                    : dangerStyle ? Theme.errorColor
                    : mouseArea.containsMouse ? Theme.primaryHover
                    : Theme.primary

    // XP-style highlight edge for 3D effect
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: mouseArea.pressed ? 0 : 1
        color: mouseArea.pressed ? "transparent" : (Theme.buttonHighlight || "#FFFFFF")
        visible: !root.tonal && !root.successStyle && !root.dangerStyle
        opacity: mouseArea.containsMouse ? 0.8 : 0.5
    }

    RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        x: root.contentFillWidth ? root.contentHorizontalPadding
                                 : Math.round((parent.width - width) / 2)
        width: root.contentFillWidth
               ? Math.max(0, parent.width - root.contentHorizontalPadding * 2)
               : implicitWidth
        spacing: root.contentSpacing
        MaterialIcon {
            id: buttonIcon
            visible: root.iconName.length > 0
            icon: root.iconName
            iconSize: root.glyphSize
            color: root.contentColor
        }
        Text {
            Layout.fillWidth: root.contentFillWidth
            Layout.minimumWidth: 0
            visible: !root.compact
            text: root.text
            color: root.contentColor
            font.pixelSize: root.labelFontSize
            font.weight: root.labelFontWeight
            elide: root.labelElide
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

    HoverTips {
        visible: root.showHoverTips && root.enabled && mouseArea.containsMouse
        text: root.text
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
