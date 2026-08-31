import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root

    required property var toolController
    required property var utilities
    required property var androidBackend
    required property var jiraFeishuBackend
    property bool compact: false

    function openRecordingFolderDialog() {
        recordingWorkspace.openSaveDialog()
    }

    spacing: 14

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.toolController.selectedTool.executor.command === "recording" ? 1
                      : root.toolController.selectedTool.executor.command === "jira_feishu" ? 2
                      : 0

        InteractiveColorPicker {
            Layout.fillWidth: true
            Layout.fillHeight: true
            utilities: root.utilities
        }

        RecordingWorkspace {
            id: recordingWorkspace
            Layout.fillWidth: true
            Layout.fillHeight: true
            controller: root.utilities
            androidController: root.androidBackend
        }

        JiraFeishuWorkspace {
            Layout.fillWidth: true
            Layout.fillHeight: true
            controller: root.jiraFeishuBackend
            compact: root.compact
        }
    }
}
