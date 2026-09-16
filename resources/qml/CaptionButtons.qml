import QtQuick
import QtQuick.Controls

Rectangle {
    id: controls
    objectName: "captionButtons"
    required property var targetWindow
    property Item maximizeButton
    property bool nativeMaximizeHovered: false
    property bool nativeMaximizePressed: false
    width: Theme.captionControlsWidth; height: Theme.captionHeight
    color: Settings.dark ? "#202020" : "#f3f3f3"
    Row {
        anchors.fill: parent
        Repeater {
            model: 3
            delegate: ToolButton {
                id: button
                required property int index
                objectName: ["minimizeWindow", "maximizeWindow", "closeWindow"][index]
                width: Theme.captionButtonWidth; height: controls.height; padding: 0
                hoverEnabled: true
                Component.onCompleted: if (index === 1) controls.maximizeButton = button
                readonly property bool visualHovered: hovered || (index === 1 && controls.nativeMaximizeHovered)
                readonly property bool visualPressed: down || (index === 1 && controls.nativeMaximizePressed)
                readonly property bool restored: controls.targetWindow.visibility === Window.Maximized
                readonly property color glyphColor: index === 2 && (hovered || down) ? "white" : Settings.dark ? "#f5f5f5" : "#1a1a1a"
                Accessible.name: index === 0 ? "最小化" : index === 1 ? (restored ? "还原" : "最大化") : "关闭"
                background: Rectangle {
                    color: button.index === 2 && (button.visualHovered || button.visualPressed)
                           ? (button.visualPressed ? "#c42b1c" : "#e81123")
                           : button.visualPressed ? (Settings.dark ? "#484848" : "#cccccc")
                           : button.visualHovered ? (Settings.dark ? "#353535" : "#e5e5e5") : controls.color
                }
                contentItem: Item {
                    Rectangle {
                        visible: button.index === 0
                        anchors.centerIn: parent; width: 10; height: 1; color: button.glyphColor
                    }
                    Item {
                        visible: button.index === 1
                        anchors.centerIn: parent; width: 10; height: 10
                        Rectangle { visible: button.restored; x: 2; width: 8; height: 8; color: button.background.color; border.color: button.glyphColor }
                        Rectangle { y: button.restored ? 2 : 0; width: button.restored ? 8 : 10; height: width; color: button.background.color; border.color: button.glyphColor }
                    }
                    Item {
                        visible: button.index === 2
                        anchors.centerIn: parent; width: 10; height: 10
                        Rectangle { anchors.centerIn: parent; width: 13; height: 1; rotation: 45; color: button.glyphColor }
                        Rectangle { anchors.centerIn: parent; width: 13; height: 1; rotation: -45; color: button.glyphColor }
                    }
                }
                onClicked: {
                    if (index === 0) controls.targetWindow.showMinimized()
                    else if (index === 1) restored ? controls.targetWindow.showNormal() : controls.targetWindow.showMaximized()
                    else controls.targetWindow.close()
                }
            }
        }
    }
}
