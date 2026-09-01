import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    required property string title
    required property string description
    required property string iconName
    required property string executorKind
    required property bool selected
    property bool running: false
    property bool draggable: false
    property Item dragTarget: null
    property real dragMinimumX: 0
    property real dragMaximumX: 0
    property real dragMinimumY: 0
    property real dragMaximumY: 0
    property bool dragging: false

    signal clicked()
    signal dragFinished(real centerX, real centerY)

    radius: Theme.radiusMedium
    color: root.selected
           ? (Theme.cardSelected || Theme.primaryContainer)
           : (cardMouse.containsMouse || root.dragging
                ? (Theme.cardHover || Theme.surfaceContainerHigh) : (Theme.cardDefault || Theme.surfaceContainerLow))
    border.color: root.selected || root.dragging ? (Theme.borderColorFocused || Theme.primary) : Theme.outlineVariant
    border.width: root.selected || root.dragging ? 2 : 1
    z: root.dragging ? 10 : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusSmall
            color: root.selected ? Theme.surface : Theme.primaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                icon: root.iconName
                iconSize: 23
                color: Theme.primary
            }

            Rectangle {
                visible: root.running
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -3
                anchors.topMargin: -3
                width: 10
                height: 10
                radius: height / 2
                color: Theme.success
                border.color: Theme.surface
                border.width: 2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.selected ? Theme.primaryText : Theme.textPrimary
                font.pixelSize: Theme.fontComponentTitle
                font.weight: root.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: kindText.implicitWidth + 12
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusTiny
                    color: root.selected ? Theme.surface : (Theme.cardHover || Theme.surfaceContainer)
                    border.color: Theme.outlineVariant
                    border.width: 1

                    Text {
                        id: kindText
                        anchors.centerIn: parent
                        text: root.executorKind
                        color: root.selected ? Theme.primaryText : Theme.textSecondary
                        font.pixelSize: Theme.fontMicro
                        font.family: "Cascadia Mono"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.description || "暂无功能说明"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }
        }

        MaterialIcon {
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignVCenter
            icon: "chevron_right"
            iconSize: 20
            color: root.selected ? Theme.primary : Theme.textSecondary
        }
    }

    ToolTip.visible: cardMouse.containsMouse
    ToolTip.text: root.description
        ? root.title + "\n" + root.description
        : root.title
    ToolTip.delay: 600

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property bool suppressClick: false
        drag.target: root.dragging ? root.dragTarget : null
        drag.axis: Drag.XAndYAxis
        drag.minimumX: root.dragMinimumX
        drag.maximumX: root.dragMaximumX
        drag.minimumY: root.dragMinimumY
        drag.maximumY: root.dragMaximumY
        onPressAndHold: {
            if (root.draggable && root.dragTarget) {
                suppressClick = true
                root.dragging = true
            }
        }
        onReleased: {
            if (root.dragging && root.dragTarget) {
                root.dragFinished(
                    root.dragTarget.x + root.dragTarget.width / 2,
                    root.dragTarget.y + root.dragTarget.height / 2)
            }
            root.dragging = false
        }
        onClicked: {
            if (!suppressClick)
                root.clicked()
            suppressClick = false
        }
        onCanceled: {
            root.dragging = false
            suppressClick = false
        }
    }
}
