import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Dialog {
    id: dialog
    property string kind: "powershell"
    property string selectedVersion: ""
    readonly property string pluginName: kind === "python" ? "Python" : "PowerShell 7"
    readonly property bool ready: kind === "python" ? Plugins.pythonReady : Plugins.powerShellReady
    readonly property string activeVersion: kind === "python" ? Plugins.pythonVersion : Plugins.powerShellVersion
    readonly property var availableVersions: kind === "python" ? Plugins.pythonVersions : Plugins.powerShellVersions
    readonly property var selectedInfo: versions.currentIndex >= 0 ? (availableVersions[versions.currentIndex] || ({})) : ({})
    onKindChanged: selectedVersion=""
    title: pluginName+" 插件"
    anchors.centerIn: parent; modal: true
    width: Math.min(560,parent.width-40); height: Math.min(510,parent.height-40); padding: 20
    background: Rectangle { radius: 10; color: Theme.surface; border.color: Theme.border }
    header: Label { text: dialog.title; color: Theme.text; font.pixelSize: 21; font.bold: true; padding: 20; bottomPadding: 12 }
    ColumnLayout {
        anchors.fill: parent; spacing: 14
        RowLayout { Layout.fillWidth: true; spacing: 12
            Rectangle { implicitWidth: 44; implicitHeight: 44; radius: 7; color: Theme.selected
                Icon { anchors.centerIn: parent; name: dialog.kind === "python" ? "code" : "terminal"; color: Theme.accent }
            }
            ColumnLayout { Layout.fillWidth: true; spacing: 4
                Label { text: dialog.ready ? "当前版本："+dialog.activeVersion : "尚未安装可用的 "+dialog.pluginName; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Label { text: dialog.ready ? "切换版本不会结束现有会话" : "安装前仍可编辑和保存脚本"; color: Theme.muted; font.pixelSize: 12 }
            }
        }
        Label { text: "选择版本"; font.pixelSize: 12 }
        SelectField { id: versions; objectName: "pluginVersionSelector"; model: dialog.availableVersions; textRole: "version"; valueRole: "version"; Layout.fillWidth: true; enabled: !Plugins.busy
            currentIndex: { const entries=dialog.availableVersions; if(count===0)return -1; const index=indexOfValue(dialog.selectedVersion); return index>=0?index:0 }
            onActivated: dialog.selectedVersion=currentValue
        }
        Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12
            text: versions.count===0 ? "暂无可选版本，请刷新版本列表。" : dialog.selectedInfo.active && dialog.selectedInfo.installed ? "此版本正在使用。" : dialog.selectedInfo.installed ? "此版本已安装，可切换使用；现有会话继续使用原版本。" : "将下载并校验所选版本；安装成功后由你再次运行脚本或打开终端。"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
        Label { Layout.fillWidth: true; visible: Plugins.busy; wrapMode: Text.Wrap; font.bold: true
            text: "当前任务："+(Plugins.taskKind === "python" ? "Python" : "PowerShell 7")+" "+Plugins.taskVersion
        }
        ProgressBar { visible: Plugins.busy; value: Plugins.progress/100; Layout.fillWidth: true }
        ScrollView { id: statusScroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
            ScrollBar.vertical.active: true
            Label { width: statusScroll.availableWidth; text: Plugins.status || (dialog.ready ? "当前插件可正常使用。" : "准备就绪，点击下方按钮开始。"); wrapMode: Text.Wrap; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12 }
        }
        Label { text: Plugins.catalogStatus; visible: text.length>0; Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12 }
        RowLayout { Layout.fillWidth: true
            ActionButton { text: Plugins.catalogRefreshing ? "正在刷新" : "刷新版本"; enabled: !Plugins.busy && !Plugins.catalogRefreshing; onClicked: Plugins.refreshCatalog() }
            Item { Layout.fillWidth: true }
            ActionButton { text: "关闭"; onClicked: dialog.close() }
            ActionButton { text: Plugins.cancellationRequested ? "正在取消" : "取消安装"; visible: Plugins.busy; enabled: !Plugins.cancellationRequested; onClicked: Plugins.cancel() }
            ActionButton { text: dialog.selectedInfo.installed ? "使用此版本" : "安装此版本"; primary: true; visible: !Plugins.busy
                enabled: versions.currentIndex>=0 && !(dialog.selectedInfo.active && dialog.selectedInfo.installed)
                onClicked: Plugins.install(dialog.kind,versions.currentValue)
            }
        }
    }
}
