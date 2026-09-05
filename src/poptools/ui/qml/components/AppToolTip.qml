import QtQuick
import QtQuick.Controls

Item {
    id: root

    property Item target: parent
    property string text: ""
    property int delay: 0
    property int timeout: -1
    readonly property bool useNativeToolTip:
        platformUiController !== null
        && platformUiController.nativeToolTipsEnabled

    width: 0
    height: 0

    function showNativeToolTip() {
        if (!root.visible || !root.text || !root.target)
            return
        var point = root.target.mapToGlobal(
            root.target.width / 2, root.target.height + 8)
        if (platformUiController !== null) {
            platformUiController.showNativeToolTip(
                root.text, Math.round(point.x), Math.round(point.y), root.timeout)
        }
    }

    function hideNativeToolTip() {
        nativeDelay.stop()
        if (root.useNativeToolTip && platformUiController !== null)
            platformUiController.hideNativeToolTip()
    }

    onVisibleChanged: {
        if (!useNativeToolTip)
            return
        if (visible) {
            if (delay > 0)
                nativeDelay.restart()
            else
                showNativeToolTip()
        } else {
            hideNativeToolTip()
        }
    }
    onTextChanged: {
        if (useNativeToolTip && visible) {
            hideNativeToolTip()
            if (delay > 0)
                nativeDelay.restart()
            else
                showNativeToolTip()
        }
    }
    Component.onDestruction: hideNativeToolTip()

    Timer {
        id: nativeDelay
        interval: Math.max(1, root.delay)
        repeat: false
        onTriggered: root.showNativeToolTip()
    }

    ToolTip {
        parent: root.target
        x: Math.round((root.target.width - implicitWidth) / 2)
        y: root.target.height
        visible: !root.useNativeToolTip && root.visible
        text: root.text
        delay: root.delay
        timeout: root.timeout
    }
}
