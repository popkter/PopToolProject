import QtQuick
import QtQuick.Controls

// Desktop scrolling uses the wheel, touchpad or scroll bars.  Disabling mouse
// dragging prevents an in-progress scroll from consuming the next left click
// intended for a child control. Touch flicking remains available.
ScrollView {
    id: root

    function disableMouseDragging() {
        if (contentItem && "acceptedButtons" in contentItem)
            contentItem["acceptedButtons"] = Qt.NoButton
    }

    onContentItemChanged: disableMouseDragging()
    Component.onCompleted: disableMouseDragging()
}
