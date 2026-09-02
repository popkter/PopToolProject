import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    clip: true
    required property string label
    required property string iconName
    property bool selected: false
    property bool compact: false
    property bool dense: false
    property string actionText: ""
    property string actionIconName: "system_update"
    signal clicked()
    signal actionClicked()

    implicitHeight: dense ? 58 : 66
    radius: Theme.radiusLarge
    color: selected ? (Theme.cardSelected || Theme.primaryContainer)
                   : (mouseArea.containsMouse ? (Theme.cardHover || Theme.surfaceContainer) : "transparent")

    RowLayout {
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 0 : Theme.pagePadding
        anchors.rightMargin: root.actionText.length > 0
                             ? (root.compact ? 0 : actionButton.width + Theme.pagePadding)
                             : (root.compact ? 0 : Theme.space16)
        spacing: root.compact ? 0 : Theme.sectionSpacing

        Item { visible: root.compact; Layout.fillWidth: true }
        MaterialIcon {
            icon: root.iconName
            iconSize: 27
            color: root.selected ? Theme.primary : Theme.textPrimary
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
        Text {
            visible: !root.compact
            text: root.label
            color: root.selected ? Theme.primary : Theme.textPrimary
            font.pixelSize: Theme.fontComponentTitle
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
        }
        Item { visible: root.compact; Layout.fillWidth: true }
    }

    Rectangle {
        id: actionButton
        z: 2
        visible: root.actionText.length > 0
        anchors.right: parent.right
        anchors.rightMargin: root.compact ? Theme.space4 : Theme.space12
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? 28 : actionLabel.implicitWidth + 18
        height: root.compact ? 28 : 34
        radius: height / 2
        color: actionMouse.containsMouse
               ? Theme.primaryContainerHover : Theme.primaryContainer

        MaterialIcon {
            visible: root.compact
            anchors.centerIn: parent
            icon: root.actionIconName
            iconSize: 17
            color: Theme.primaryText
        }
        Text {
            id: actionLabel
            visible: !root.compact
            anchors.centerIn: parent
            text: root.actionText
            color: Theme.primaryText
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }
        ToolTip.visible: root.compact && actionMouse.containsMouse
        ToolTip.text: root.actionText
        ToolTip.delay: 450
        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }

    ToolTip.visible: root.compact && mouseArea.containsMouse
    ToolTip.text: root.label
    ToolTip.delay: 450

    MouseArea {
        id: mouseArea
        z: 0
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
