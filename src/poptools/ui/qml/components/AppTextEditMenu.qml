import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property var target

    anchors.fill: parent
    z: 200

    function hasSelection() {
        return root.target && String(root.target.selectedText || "").length > 0
    }

    function isEditable() {
        return root.target && !root.target.readOnly
    }

    function deleteSelection() {
        if (!root.hasSelection() || !root.isEditable())
            return
        root.target.remove(root.target.selectionStart, root.target.selectionEnd)
    }

    // Keep context-menu handling independent of the primary-button focus path,
    // so the editor retains native cursor placement and selection behavior.
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.WithinBounds
        onTapped: function(eventPoint) {
            root.target.forceActiveFocus()
            if (!root.hasSelection() && root.target.positionAt) {
                root.target.cursorPosition = root.target.positionAt(
                    eventPoint.position.x, eventPoint.position.y)
            }
            editMenu.x = Math.round(eventPoint.position.x)
            editMenu.y = Math.round(eventPoint.position.y)
            editMenu.open()
        }
    }

    AppMenu {
        id: editMenu
        objectName: "appTextEditMenu"

        AppMenuItem {
            text: "撤销"
            enabled: root.isEditable() && root.target.canUndo
            onTriggered: root.target.undo()
        }
        AppMenuItem {
            text: "重做"
            enabled: root.isEditable() && root.target.canRedo
            onTriggered: root.target.redo()
        }
        AppMenuSeparator {}
        AppMenuItem {
            text: "剪切"
            enabled: root.isEditable() && root.hasSelection()
            onTriggered: root.target.cut()
        }
        AppMenuItem {
            text: "复制"
            enabled: root.hasSelection()
            onTriggered: root.target.copy()
        }
        AppMenuItem {
            text: "粘贴"
            enabled: root.isEditable()
            onTriggered: root.target.paste()
        }
        AppMenuItem {
            text: "删除"
            destructive: true
            enabled: root.isEditable() && root.hasSelection()
            onTriggered: root.deleteSelection()
        }
        AppMenuSeparator {}
        AppMenuItem {
            text: "全选"
            enabled: root.target && root.target.length > 0
            onTriggered: root.target.selectAll()
        }
    }
}
