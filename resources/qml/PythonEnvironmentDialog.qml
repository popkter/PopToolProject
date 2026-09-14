import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Dialog {
    id: dialog
    anchors.centerIn: parent; width: Math.min(820,parent.width-80); height: Math.min(780,parent.height-80); modal: true
    title: "Python 依赖环境"
    standardButtons: Dialog.Close
    onOpened: Python.refresh()
    ColumnLayout { anchors.fill: parent; spacing: 12
        Label { text: Python.status || "使用应用内 Python 和私有依赖环境"; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Label { text: Python.information.prefix || Plugins.pythonDirectory(); color: Theme.muted; elide: Text.ElideMiddle; Layout.fillWidth: true; font.pixelSize: 12 }
        RowLayout { Layout.fillWidth: true
            Field { id: packageNames; Layout.fillWidth: true; placeholderText: "包名，例如 requests 或 Pillow>=10" }
            ActionButton { text: "安装"; primary: true; enabled: !Python.busy; onClicked: Python.installPackages(packageNames.text) }
            ActionButton { text: "刷新"; enabled: !Python.busy; onClicked: Python.refresh() }
        }
        Label { text: "依赖修改会等待使用此环境的脚本与终端结束；等待期间暂停新任务启动。"; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        ListView { id: packages; model: Python.packages; Layout.fillWidth: true; Layout.preferredHeight: 200; clip: true; ScrollBar.vertical: ScrollBar {}
            delegate: RowLayout { required property var modelData; width: packages.width; height: 30
                Label { text: modelData.name; Layout.fillWidth: true }
                Label { text: modelData.version; color: Theme.muted }
            }
        }
        Label { text: "操作日志"; font.bold: true }
        ScrollView { Layout.fillWidth: true; Layout.fillHeight: true
            TextArea { text: Python.log; readOnly: true; selectByMouse: true; font.family: Settings.fontFamily; font.pixelSize: 12; wrapMode: TextEdit.Wrap }
        }
        RowLayout { Layout.fillWidth: true
            BusyIndicator { running: Python.busy && !Python.queued; visible: Python.busy; implicitWidth: 28; implicitHeight: 28 }
            Item { Layout.fillWidth: true }
            ActionButton { text: "复制日志"; onClicked: App.copyText(Python.log) }
            ActionButton { text: "取消操作"; visible: Python.busy; onClicked: Python.cancel() }
        }
    }
}
