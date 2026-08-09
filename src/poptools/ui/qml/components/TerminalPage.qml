pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    required property var controller

    // Page roots always occupy the complete workspace. DeveloperConsole owns
    // the shared Theme.pagePadding inside that boundary.
    DeveloperConsole {
        anchors.fill: parent
        controller: root.controller
    }
}
