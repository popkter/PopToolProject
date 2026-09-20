pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    required property var controller
    required property var parentWindow
    signal createScriptRequested(string command, string kind)

    // The terminal intentionally fills the complete workspace so it behaves
    // like a native command-line surface rather than a padded content page.
    DeveloperConsole {
        anchors.fill: parent
        controller: root.controller
        parentWindow: root.parentWindow
        onCreateScriptRequested: function(command, kind) {
            root.createScriptRequested(command, kind)
        }
    }
}
