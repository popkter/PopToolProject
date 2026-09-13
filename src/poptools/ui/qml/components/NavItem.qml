import QtQuick
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

    implicitHeight: compact ? 40 : (dense ? 48 : 52)
    radius: compact ? Theme.radiusSmall : Theme.radiusMedium
    color: selected ? "#E8F2FF"
                   : (mouseArea.containsMouse ? "#EEF1F5" : "transparent")
    border.width: compact ? 1 : 0
    border.color: selected ? "#88BFFF" : "#E0E5EB"

    RowLayout {
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 0 : Theme.space16
        anchors.rightMargin: root.actionText.length > 0
                             ? (root.compact ? 0 : actionButton.width + Theme.pagePadding)
                             : (root.compact ? 0 : Theme.space12)
        spacing: root.compact ? 0 : Theme.space12

        Item { visible: root.compact; Layout.fillWidth: true }
        MaterialIcon {
            icon: root.iconName
            iconSize: root.compact ? 20 : 21
            color: root.selected ? "#1478E8" : "#53606F"
            Layout.preferredWidth: 24
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
        Text {
            visible: !root.compact
            text: root.label
            color: root.selected ? Theme.primary : Theme.textPrimary
            font.pixelSize: 15
            font.weight: root.selected ? Font.Bold : Font.Medium
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
        HoverTips {
            visible: root.compact && actionMouse.containsMouse
            text: root.actionText
        }
        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }

    HoverTips {
        visible: root.compact && mouseArea.containsMouse
        text: root.label
    }

    MouseArea {
        id: mouseArea
        z: 0
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
