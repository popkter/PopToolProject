import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id: page
    readonly property var parameterValues: Scripts.parameterValues

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 28; spacing: 22
        RowLayout { Layout.fillWidth: true
            ColumnLayout { spacing: 4
                Text { text: "自定义"; font.pixelSize: 30; font.bold: true; color: Theme.text }
                Text { text: "管理与运行常用脚本"; font.pixelSize: 12; color: Theme.muted }
            }
            Item { Layout.fillWidth: true }
            ActionButton { text: "导入 JSON"; onClicked: App.importClipboard() }
            ActionButton { text: "+ 新建脚本"; primary: true; onClicked: App.newScript() }
        }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 18
            Rectangle { Layout.preferredWidth: Math.max(300,page.width*0.34); Layout.fillHeight: true; radius: 9; color: Theme.surface; border.color: Theme.border
                ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                    Field { Layout.fillWidth: true; placeholderText: "搜索脚本名称、描述或类型"; onTextEdited: Scripts.query=text }
                    RowLayout { spacing: 3; Layout.fillWidth: true
                        Repeater { model: [{label:"全部",value:"all"},{label:"PS",value:"powershell"},{label:"Python",value:"python"},{label:"CMD",value:"cmd"},{label:"收藏",value:"favorite"}]
                            ActionButton { required property var modelData; text: modelData.label; selected: Scripts.languageFilter === modelData.value; font.pixelSize: 11; implicitHeight: 28; leftPadding: 6; rightPadding: 6; Layout.fillWidth: true; onClicked: Scripts.languageFilter=modelData.value }
                        }
                    }
                    RowLayout { Layout.fillWidth: true
                        Text { text: "脚本名称"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                        SelectField { model: [{label:"添加时间",value:"added_time"},{label:"名称",value:"name"},{label:"使用次数",value:"usage"},{label:"最近使用",value:"recent"},{label:"自定义",value:"custom"}]; textRole: "label"; valueRole: "value"; currentIndex: ["added_time","name","usage","recent","custom"].indexOf(Scripts.sortMode); implicitWidth: 118; onActivated: Scripts.sortMode=currentValue }
                    }
                    ListView { id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: Scripts; spacing: 3
                        property string draggedId: ""
                        property int dropIndex: -1
                        property real pointerY: 0
                        property bool dragging: false
                        property int dragFrom: -1
                        function updateDrop(y) { pointerY=y; let hit=indexAt(width/2,y+contentY);if(hit<0)hit=indexAt(width/2,y+contentY+spacing);dropIndex=hit>=0?hit:(y<0?0:count-1) }
                        Timer { interval: 60; running: list.dragging; repeat: true; onTriggered: {
                            if(list.pointerY<24)list.contentY=Math.max(list.originY,list.contentY-18)
                            else if(list.pointerY>list.height-24)list.contentY=Math.min(list.originY+Math.max(0,list.contentHeight-list.height),list.contentY+18)
                            list.updateDrop(list.pointerY)
                        } }
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            id: scriptRow
                            required property int index
                            required property string scriptId
                            required property string title
                            required property string description
                            required property string language
                            required property string iconName
                            required property bool selected
                            required property bool running
                            required property bool favorite
                            width: list.width; height: 40
                            ToolTip.visible: hovered && description.length>0
                            ToolTip.text: description
                            ToolTip.delay: 700
                            background: Rectangle { radius: 6; color: selected ? Theme.selected : parent.hovered ? Theme.field : "transparent" }
                            contentItem: RowLayout { spacing: 10
                                Item {
                                    visible: Scripts.sortMode === "custom"; Layout.preferredWidth: 24; Layout.fillHeight: true
                                    Icon { anchors.centerIn: parent; name: "drag_indicator" }
                                    MouseArea {
                                        objectName: "scriptDrag_"+index
                                        anchors.fill: parent; preventStealing: true; cursorShape: pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
                                        property real startY: 0
                                        onPressed: (mouse) => { startY=mouse.y;list.draggedId=scriptId;list.dropIndex=index;list.dragFrom=index }
                                        onPositionChanged: (mouse) => {
                                            if(!pressed)return
                                            if(Math.abs(mouse.y-startY)>Qt.styleHints.startDragDistance)list.dragging=true
                                            if(list.dragging)list.updateDrop(mapToItem(list,mouse.x,mouse.y).y)
                                        }
                                        onReleased: {
                                            const id=list.draggedId;const target=list.dropIndex;const moved=list.dragging
                                            list.dragging=false;list.draggedId="";list.dropIndex=-1
                                            if(moved)Scripts.move(id,target)
                                        }
                                        onCanceled: { list.dragging=false;list.draggedId="";list.dropIndex=-1 }
                                    }
                                }
                                Icon { name: running ? "play_circle" : iconName || "terminal"; color: selected ? Theme.accent : Theme.muted }
                                Text { text: title; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { visible: favorite; text: "★"; color: Theme.accent; font.pixelSize: 11 }
                                Rectangle { Layout.preferredWidth: 78; Layout.preferredHeight: 22; radius: 4
                                    color: Settings.dark ? Theme.field : language === "python" ? "#f5efff" : language === "powershell" ? "#edf4ff" : "#edf8f1"
                                    Text { anchors.centerIn: parent; text: language === "powershell" ? "PowerShell" : language === "python" ? "Python" : "CMD"
                                        color: Settings.dark ? Theme.muted : language === "python" ? "#8962b5" : language === "powershell" ? "#567baa" : "#4f8a66"; font.pixelSize: 10
                                    }
                                }
                                Icon { name: "chevron_right"; color: Theme.muted; font.pixelSize: 16 }
                            }
                            onClicked: Scripts.select(scriptId)
                            Rectangle { anchors.left: parent.left; anchors.right: parent.right; y: index>=list.dragFrom?parent.height-3:0; height: 3; color: Theme.accent; visible: list.dragging && list.dropIndex===index }
                        }
                        Label { anchors.centerIn: parent; visible: list.count === 0; text: Scripts.count === 0 ? "还没有脚本\n点击右上角新建" : "没有匹配的脚本"; color: Theme.muted; horizontalAlignment: Text.AlignHCenter }
                    }
                    Label { text: "显示 "+list.count+" 个脚本"; color: Theme.muted; font.pixelSize: 11 }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 9; color: Theme.surface; border.color: Theme.border
                Label { anchors.centerIn: parent; visible: !Scripts.selected.id; text: "选择脚本以查看详情"; color: Theme.muted }
                ColumnLayout { anchors.fill: parent; anchors.margins: 20; spacing: 16; visible: !!Scripts.selected.id
                    RowLayout { Layout.fillWidth: true
                        Rectangle { Layout.preferredWidth: 44; Layout.preferredHeight: 44; Layout.alignment: Qt.AlignTop; radius: 7; color: Theme.selected
                            Icon { anchors.centerIn: parent; name: Scripts.selected.icon || "code"; color: Theme.accent; font.pixelSize: 24 }
                        }
                        ColumnLayout { Layout.fillWidth: true; spacing: 6
                            Text { text: Scripts.selected.title || ""; color: Theme.text; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { id: descriptionPreview; objectName: "scriptDescriptionPreview"; text: Scripts.selected.description || ""; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                            ToolButton { objectName: "scriptDescriptionOpen"; visible: descriptionPreview.truncated; text: "查看完整说明"; implicitHeight: 26; leftPadding: 0; rightPadding: 0
                                contentItem: Text { text: parent.text; color: Theme.accent; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                onClicked: descriptionDialog.open()
                            }
                            Rectangle { implicitWidth: languageLabel.implicitWidth+16; implicitHeight: 22; radius: 4; color: Theme.field
                                Text { id: languageLabel; anchors.centerIn: parent; text: Scripts.selected.language === "powershell" ? "PowerShell 7" : Scripts.selected.language === "python" ? "Python" : "CMD"; color: Theme.muted; font.pixelSize: 11 }
                            }
                        }
                        ToolButton { Layout.alignment: Qt.AlignTop; text: Scripts.selected.favorite ? "★" : "☆"; onClicked: Scripts.toggleFavorite(Scripts.selected.id) }
                        ActionButton { Layout.alignment: Qt.AlignTop; text: "分享"; onClicked: App.shareScript() }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
                    Label { text: "外部运行要求："+(Scripts.selected.externalRequirements || []).join("、")+"。请确认运行条件已满足。"; visible: (Scripts.selected.externalRequirements || []).length>0; Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12 }
                    Label { readonly property int fileCount: Object.keys(Scripts.selected.bundledFiles || {}).length; readonly property int directoryCount: (Scripts.selected.bundledDirectories || []).length; text: "随脚本保存 "+fileCount+" 个文件、"+directoryCount+" 个目录，分享和导出时一并包含。"; visible: fileCount>0 || directoryCount>0; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12 }
                    RowLayout { Layout.fillWidth: true
                        ColumnLayout { spacing: 4
                            Label { text: "参数配置"; font.bold: true }
                            Label { text: "运行前填写本次执行所需参数"+(Scripts.parameters.length>0 ? "（"+Scripts.parameters.length+" 项）" : ""); color: Theme.muted; font.pixelSize: 11 }
                        }
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "恢复默认值"; visible: Scripts.parameters.length>0; onClicked: Scripts.resetParameterValues() }
                    }
                    ScrollView { id: parameterScroll; objectName: "scriptParameterScroll"; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: Math.min(64,parameterColumn.implicitHeight); Layout.maximumHeight: 260; Layout.preferredHeight: Math.min(260,parameterColumn.implicitHeight); clip: true; contentWidth: availableWidth
                        Component.onCompleted: contentItem.boundsBehavior=Flickable.StopAtBounds
                        ScrollBar.vertical.policy: contentHeight>availableHeight ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        ColumnLayout { id: parameterColumn; width: parameterScroll.availableWidth; spacing: 10
                            Repeater { model: Scripts.parameters
                                ColumnLayout { required property var modelData; objectName: "scriptParameter_"+modelData.id; Layout.fillWidth: true; spacing: 5
                                    RowLayout { Layout.fillWidth: true
                                        Label { text: modelData.label; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Label { text: modelData.required ? "必填" : "可选"; color: Theme.muted; font.pixelSize: 10 }
                                    }
                                    RowLayout { Layout.fillWidth: true
                                        Field { id: parameter; Layout.fillWidth: true; visible: modelData.kind !== "choice" && modelData.kind !== "multiline" && modelData.kind !== "boolean"; text: Scripts.parameterValues[modelData.id] || ""; onTextEdited: Scripts.setParameterValue(modelData.id,text)
                                            placeholderText: modelData.placeholder || (modelData.kind === "file" ? "选择或拖入一个文件" : modelData.kind === "directory" ? "选择或拖入一个目录" : "")
                                            echoMode: modelData.kind === "secret" ? TextInput.Password : TextInput.Normal
                                            inputMethodHints: modelData.kind === "secret" ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
                                            DropArea { id: fileDrop; anchors.fill: parent; enabled: modelData.kind === "file" || modelData.kind === "directory"
                                                objectName: "parameterDrop_"+modelData.id
                                                onEntered: (drag) => { drag.accepted=drag.hasUrls && drag.urls.length===1 && (drag.supportedActions & Qt.CopyAction) !== 0 }
                                                onDropped: (drop) => { if((drop.supportedActions & Qt.CopyAction) !== 0 && Scripts.dropParameterFile(modelData.id,drop.urls))drop.accept(Qt.CopyAction);else drop.accepted=false }
                                            }
                                            Rectangle { anchors.fill: parent; visible: fileDrop.containsDrag; color: "transparent"; radius: 6; border.width: 2; border.color: Theme.accent }
                                        }
                                        SelectField { Layout.fillWidth: true; visible: modelData.kind === "choice"; model: modelData.options; textRole: "label"; valueRole: "value"; currentIndex: count > 0 ? indexOfValue(Scripts.parameterValues[modelData.id]) : -1; onActivated: Scripts.setParameterValue(modelData.id,currentValue) }
                                        CheckBox { Layout.fillWidth: true; visible: modelData.kind === "boolean"; text: "启用"; checked: Scripts.parameterValues[modelData.id] === true; onToggled: Scripts.setBooleanParameter(modelData.id,checked) }
                                        ScrollView { id: multilineScroll; Layout.fillWidth: true; Layout.preferredHeight: 100; visible: modelData.kind === "multiline"; clip: true; contentWidth: availableWidth
                                            TextArea { objectName: "multilineParameter_"+modelData.id
                                                width: multilineScroll.availableWidth
                                                text: Scripts.parameterValues[modelData.id] || ""; textFormat: TextEdit.PlainText; wrapMode: TextEdit.Wrap; selectByMouse: true
                                                color: Theme.text; selectionColor: Theme.accent; placeholderTextColor: Theme.muted; font.pixelSize: 13; padding: 11
                                                placeholderText: modelData.placeholder || "输入多行文本"
                                                onTextChanged: { if(activeFocus && text !== Scripts.parameterValues[modelData.id]) Scripts.setParameterValue(modelData.id,text) }
                                                background: Rectangle { radius: 6; color: Theme.surface; border.color: parent.activeFocus ? Theme.accent : Theme.border }
                                            }
                                        }
                                        ActionButton { text: "选择文件"; visible: modelData.kind === "file"; onClicked: { const path=App.chooseFile(); if(path) { Scripts.setParameterValue(modelData.id,path) } } }
                                        ActionButton { text: "选择目录"; visible: modelData.kind === "directory"; onClicked: { const path=App.chooseDirectory(); if(path) Scripts.setParameterValue(modelData.id,path) } }
                                        ActionButton { text: "设为默认"; visible: modelData.kind !== "boolean" && modelData.kind !== "secret"; onClicked: Scripts.setParameterDefault(modelData.id,Scripts.parameterValues[modelData.id]) }
                                    }
                                }
                            }
                            Label { text: "此脚本没有参数"; visible: Scripts.parameters.length === 0; color: Theme.muted }
                        }
                    }
                    RowLayout { Layout.fillWidth: true
                        ActionButton { text: "编辑脚本"; enabled: !Runs.selectedRunning; onClicked: App.editScript() }
                        ActionButton { text: "删除脚本"; danger: true; enabled: !Runs.selectedRunning; onClicked: deleteDialog.open() }
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "交互运行"; enabled: !Runs.selectedRunning; onClicked: Runs.runSelected(page.parameterValues,true) }
                        ActionButton { objectName: "scriptRunButton"; text: Runs.selectedRunning ? "停止" : "▷ 运行脚本"; primary: true; onClicked: Runs.selectedRunning ? Runs.stopSelected() : Runs.runSelected(page.parameterValues,false) }
                    }
                    Rectangle { objectName: "scriptOutputPanel"; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 160; radius: 8; color: "#10151d"; clip: true
                        ColumnLayout { anchors.fill: parent; spacing: 0
                            Rectangle { Layout.fillWidth: true; height: 36; color: "#222a34"
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                                    Text { text: "控制台输出"; color: "#e5e7eb"; font.pixelSize: 12 }
                                    Text { text: Runs.outcome === "running" ? "● 运行中" : Runs.outcome === "succeeded" ? "● 已完成" : Runs.outcome === "failed" ? "● 未成功" : "尚未运行"; color: Runs.outcome === "failed" ? "#f2a0a0" : Runs.outcome === "idle" ? "#a6b4c5" : "#86d5a5"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                    ToolButton { id: copyOutput; text: "复制"; implicitHeight: 28; implicitWidth: 44
                                        contentItem: Text { text: copyOutput.text; color: "#b9c4d2"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { radius: 4; color: copyOutput.down ? "#405064" : copyOutput.hovered ? "#313d4c" : "transparent" }
                                        onClicked: App.copyText(Runs.output)
                                    }
                                    ToolButton { id: clearOutput; text: "清空"; implicitHeight: 28; implicitWidth: 44
                                        contentItem: Text { text: clearOutput.text; color: "#b9c4d2"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { radius: 4; color: clearOutput.down ? "#405064" : clearOutput.hovered ? "#313d4c" : "transparent" }
                                        onClicked: Runs.clearOutput()
                                    }
                                }
                            }
                            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true
                                TextArea { text: Runs.output; textFormat: TextEdit.PlainText; placeholderText: "运行脚本后，输出会显示在这里"; placeholderTextColor: "#738092"; padding: 14; readOnly: true; selectByMouse: true; color: "#e5e7eb"; font.family: Settings.fontFamily; font.pixelSize: 13; wrapMode: TextEdit.Wrap; background: null }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#222a34" }
                            Label { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 8
                                text: Runs.status; font.pixelSize: 11; color: Runs.outcome === "failed" ? "#f2a0a0" : Runs.outcome === "succeeded" ? "#86d5a5" : "#a6b4c5"; wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
    Dialog { id: descriptionDialog; objectName: "scriptDescriptionDialog"; title: "脚本说明"; anchors.centerIn: parent; width: Math.min(640,page.width-48); height: Math.min(480,page.height-48); modal: true; padding: 20
        background: Rectangle { radius: 10; color: Theme.surface; border.color: Theme.border }
        header: Label { text: descriptionDialog.title; color: Theme.text; font.pixelSize: 20; font.bold: true; padding: 20; bottomPadding: 12 }
        contentItem: ScrollView { id: descriptionScroll; objectName: "scriptDescriptionScroll"; clip: true; contentWidth: availableWidth
            TextArea { objectName: "scriptDescriptionText"; width: descriptionScroll.availableWidth; text: Scripts.selected.description || ""; textFormat: TextEdit.PlainText; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; padding: 0; color: Theme.text; font.pixelSize: 13; background: null }
        }
        footer: DialogButtonBox {
            padding: 12
            background: Item {}
            ActionButton { text: "关闭"; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
            onRejected: descriptionDialog.close()
        }
        onOpened: contentItem.contentItem.contentY=0
    }
    Dialog { id: deleteDialog; title: "删除脚本"; anchors.centerIn: parent; width: Math.min(480,page.width-48); implicitHeight: 220; modal: true; standardButtons: Dialog.Yes | Dialog.No
        contentItem: ScrollView { id: deleteContent; clip: true
            Label { width: deleteContent.availableWidth; wrapMode: Text.Wrap; text: "删除“"+(Scripts.selected.title || "")+"”？原文件将保留在备份目录。" }
        }
        onAccepted: Scripts.deleteSelected()
    }
}
