import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
    id: page
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ColumnLayout {
        width: page.availableWidth-56; x: 28; y: 28; spacing: 22
        ColumnLayout { spacing: 4
            Text { text: "设置"; font.pixelSize: 30; font.bold: true; color: Theme.text }
            Text { text: "应用与开发环境配置"; font.pixelSize: 12; color: Theme.muted }
        }
        RowLayout { Layout.fillWidth: true; spacing: 18; Layout.alignment: Qt.AlignTop
            ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 14
                Card { title: "外观"; subtitle: "选择应用的外观主题"; icon: "palette"; Layout.fillWidth: true
                    RowLayout { Layout.fillWidth: true
                        Repeater { model: [{label:"浅色",mode:"light",icon:"light_mode"},{label:"深色",mode:"dark",icon:"dark_mode"},{label:"跟随系统",mode:"system",icon:"desktop_windows"}]
                            ActionButton { id: themeChoice; required property var modelData; text: modelData.label; selected: Settings.themeMode === modelData.mode; Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 65; onClicked: Settings.themeMode=modelData.mode
                                contentItem: ColumnLayout { spacing: 4
                                    Icon { name: themeChoice.modelData.icon; color: themeChoice.selected ? Theme.accent : Theme.muted; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: themeChoice.text; color: themeChoice.selected ? Theme.accent : Theme.text; font.pixelSize: 12; font.bold: themeChoice.selected; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                        }
                    }
                    RowLayout { Label { text: "主题颜色" } Repeater { model: ["#0085ff","#6854e8","#168c76","#cc6734"]
                        ToolButton { required property string modelData; implicitWidth: 32; implicitHeight: 32; background: Rectangle { radius: 16; color: modelData; border.width: Settings.accent.toString() === modelData ? 3 : 0; border.color: Theme.text } onClicked: Settings.accent=modelData }
                    } }
                }
                Card { title: "脚本目录"; subtitle: "本地保存脚本与应用数据"; icon: "folder"; Layout.fillWidth: true
                    Field { text: Settings.directory; readOnly: true; Layout.fillWidth: true }
                    RowLayout { Layout.fillWidth: true
                        ActionButton { text: "导入脚本"; Layout.fillWidth: true; onClicked: App.importCollection() }
                        ActionButton { text: "导出脚本"; primary: true; Layout.fillWidth: true; onClicked: App.exportCollection() }
                    }
                    ActionButton { text: "打开数据目录"; onClicked: App.openDirectory(Settings.directory) }
                }
                Card { title: "运行设置"; subtitle: "普通脚本并发与终端显示"; icon: "tune"; Layout.fillWidth: true
                    RowLayout { Label { text: "最大并发"; Layout.fillWidth: true } SpinBox { from: 1; to: 5; value: Settings.concurrency; onValueModified: Settings.concurrency=value } }
                    RowLayout { Label { text: "终端字号"; Layout.fillWidth: true } SpinBox { from: 8; to: 40; value: Settings.fontSize; onValueModified: Settings.fontSize=value } }
                    Field { text: Settings.fontFamily; placeholderText: "终端字体"; Layout.fillWidth: true; onEditingFinished: Settings.fontFamily=text }
                    RowLayout { Label { text: "终端配色"; Layout.fillWidth: true }
                        SelectField { Layout.preferredWidth: 130; model: ["深灰","浅色","纯黑"]; currentIndex: ["slate","light","black"].indexOf(Settings.terminalScheme); onActivated: Settings.terminalScheme=["slate","light","black"][currentIndex] }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 56; radius: 6; color: Settings.terminalBackground
                        Text { anchors.centerIn: parent; text: "PS > 你好，UTerminal"; color: Settings.terminalForeground; font.family: Settings.fontFamily; font.pixelSize: Settings.fontSize }
                    }
                }
                Card { title: "应用更新"; subtitle: "当前版本："+Updates.currentVersion; icon: "system_update"; Layout.fillWidth: true
                    SelectField { Layout.fillWidth: true; model: ["手动检查","启动时检查","每日检查","每周检查"]; currentIndex: ["manual","startup","daily","weekly"].indexOf(Settings.updatePolicy); onActivated: Settings.updatePolicy=["manual","startup","daily","weekly"][currentIndex] }
                    CheckBox { text: "接收预发布版本"; checked: Settings.prerelease; onToggled: Settings.prerelease=checked }
                    Label { text: Updates.status; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Label { text: Updates.installationStatus; visible: text.length>0; color: Theme.text; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    ActionButton { text: "打开安装日志目录"; visible: Updates.installationStatus.length>0; onClicked: App.openDirectory(Settings.directory+"/updates") }
                    ActionButton { text: Updates.busy ? "正在检查…" : "检查应用更新"; enabled: !Updates.busy; onClicked: Updates.check() }
                    ProgressBar { Layout.fillWidth: true; visible: Updates.busy && Updates.progress>0; value: Updates.progress/100 }
                    RowLayout { Layout.fillWidth: true
                        ActionButton { text: "下载更新"; visible: !!Updates.available.version; enabled: !Updates.busy; onClicked: Updates.download() }
                        ActionButton { text: "取消下载"; visible: Updates.downloading; onClicked: Updates.cancelDownload() }
                    }
                    Label { text: "已下载："+(Updates.downloaded.version || ""); visible: !!Updates.downloaded.version; color: Theme.muted }
                    CheckBox { text: "退出应用后安装更新"; visible: !!Updates.downloaded.version; checked: Updates.installOnExit; onToggled: Updates.installOnExit=checked }
                    Label { text: Updates.available.notes || ""; visible: !!Updates.available.version; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.PlainText }
                }
            }
            ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 14
                Card { title: "PowerShell 7"; subtitle: "终端与 PowerShell 脚本使用此插件"; icon: "terminal"; Layout.fillWidth: true
                    Label { text: Plugins.powerShellReady ? "当前版本："+Plugins.powerShellVersion : "尚未安装"; color: Theme.muted }
                    ActionButton { text: Plugins.powerShellReady ? "管理版本" : "安装 PowerShell 7"; primary: !Plugins.powerShellReady; onClicked: App.showPlugin("powershell") }
                }
                Card { title: "Python 环境"; subtitle: "脚本、依赖检查与 pip 共用私有环境"; icon: "code"; Layout.fillWidth: true
                    Label { text: Plugins.pythonReady ? "当前版本："+Plugins.pythonVersion : "尚未安装"; color: Theme.muted }
                    ActionButton { text: Plugins.pythonReady ? "管理版本" : "安装 Python"; primary: !Plugins.pythonReady; onClicked: App.showPlugin("python") }
                    ActionButton { text: "依赖环境与包列表"; enabled: Plugins.pythonReady; onClicked: dependencies.open() }
                }
                Card { title: "插件任务"; subtitle: "下载、校验与解压进度"; icon: "download"; Layout.fillWidth: true
                    SelectField { Layout.fillWidth: true; model: ["手动检查插件更新","每日检查插件更新","每周检查插件更新"]; currentIndex: ["manual","daily","weekly"].indexOf(Settings.pluginUpdatePolicy); onActivated: Settings.pluginUpdatePolicy=["manual","daily","weekly"][currentIndex] }
                    ActionButton { text: Plugins.catalogRefreshing ? "正在刷新版本" : "检查插件版本"; enabled: !Plugins.catalogRefreshing; onClicked: Plugins.refreshCatalog() }
                    Label { text: Plugins.catalogStatus; visible: text.length>0; wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.PlainText; color: Theme.muted }
                    Label { text: Plugins.status || "没有进行中的安装"; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.muted }
                    ProgressBar { Layout.fillWidth: true; value: Plugins.progress/100; visible: Plugins.busy }
                    ActionButton { text: "取消安装"; visible: Plugins.busy; onClicked: Plugins.cancel() }
                }
                Card { title: "关于 UTerminal"; subtitle: "Windows 终端与自定义脚本"; icon: "info"; Layout.fillWidth: true
                    Label { text: "UTerminal "+Updates.currentVersion+"\nQt 6 · C++ · QML"; color: Theme.muted }
                    Label { text: "Ctrl+T 新标签 · Ctrl+Tab 切换标签\nCtrl+C 复制选区 / 中断 · Ctrl+V 粘贴"; color: Theme.muted; font.pixelSize: 12 }
                }
            }
        }
        Item { Layout.preferredHeight: 28 }
    }
    PythonEnvironmentDialog { id: dependencies }
}
