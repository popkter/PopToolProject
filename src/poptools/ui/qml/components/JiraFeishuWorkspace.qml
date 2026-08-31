import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root
    objectName: "jiraFeishuWorkspace"

    required property var controller
    property bool compact: false
    readonly property bool narrow: width < 760
    property var profile: ({})
    property bool outputExpanded: false
    property real outputReveal: outputExpanded ? 1 : 0
    readonly property real outputPanelCollapsedHeight: 66
    readonly property real outputLogMaxHeight: Math.max(
        0,
        height - headerCard.height - outputPanelCollapsedHeight - root.spacing
    )

    spacing: 8

    Behavior on outputReveal {
        NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
    }

    function value(section, key, fallback) {
        if (!profile || !profile[section] || profile[section][key] === undefined)
            return fallback
        return profile[section][key]
    }

    function reloadProfile() {
        profile = controller.currentProfile
        profileName.text = profile.name || ""
        jiraUrl.text = value("jira", "base_url", "")
        jiraToken.text = value("jira", "token", "")
        jiraJql.text = value("jira", "jql_filter", "")
        jiraMax.value = Number(value("jira", "max_results", 200))
        webhook.text = value("feishu", "webhook_url", "")
        keyword.text = value("feishu", "keyword", "")
        signSecret.text = value("feishu", "secret", "")
        appId.text = value("feishu", "app_id", "")
        appSecret.text = value("feishu", "app_secret", "")
        atAssignee.checked = Boolean(value("message", "at_assignee", true))
        emailDomain.text = value("message", "email_domain", "@geely.com")
        scheduleEnabled.checked = Boolean(value("schedule", "enabled", false))
        scheduleMode.currentIndex = value("schedule", "mode", "interval") === "daily" ? 1 : 0
        intervalMinutes.value = Number(value("schedule", "interval_minutes", 60))
        var times = value("schedule", "daily_times", ["09:00", "15:00", "18:00"])
        dailyTimes.text = times && times.join ? times.join(",") : String(times)
    }

    function commitForm() {
        controller.updateField("root", "name", profileName.text.trim())
        controller.updateField("jira", "base_url", jiraUrl.text.trim())
        controller.updateField("jira", "token", jiraToken.text)
        controller.updateField("jira", "jql_filter", jiraJql.text)
        controller.updateField("jira", "max_results", jiraMax.value)
        controller.updateField("feishu", "webhook_url", webhook.text.trim())
        controller.updateField("feishu", "keyword", keyword.text.trim())
        controller.updateField("feishu", "secret", signSecret.text)
        controller.updateField("feishu", "app_id", appId.text.trim())
        controller.updateField("feishu", "app_secret", appSecret.text)
        controller.updateField("message", "at_assignee", atAssignee.checked)
        controller.updateField("message", "email_domain", emailDomain.text.trim() || "@geely.com")
        controller.updateField("schedule", "enabled", scheduleEnabled.checked)
        controller.updateField("schedule", "mode", scheduleMode.currentIndex === 0 ? "interval" : "daily")
        controller.updateField("schedule", "interval_minutes", intervalMinutes.value)
        controller.updateDailyTimes(dailyTimes.text)
    }

    function runCurrent(action) {
        commitForm()
        controller.runAction(action)
    }

    component FieldLabel: Text {
        color: Theme.textSecondary
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Medium
    }

    component AppField: TextField {
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        leftPadding: 14
        rightPadding: 14
        color: Theme.textPrimary
        placeholderTextColor: Theme.textSecondary
        selectByMouse: true
        font.pixelSize: Theme.fontBody
        background: Rectangle {
            radius: Theme.radiusMedium
            color: Theme.surface
            border.color: parent.activeFocus ? Theme.primary : Theme.outline
            border.width: parent.activeFocus ? 2 : 1
        }
    }

    component MiniButton: Rectangle {
        id: mini
        property string text: ""
        property string iconName: ""
        property bool danger: false
        signal clicked()
        implicitHeight: 46
        implicitWidth: 88
        radius: Theme.radiusMedium
        color: danger ? (hover.containsMouse ? Qt.darker(Theme.errorContainer, 1.05) : Theme.errorContainer)
                      : (hover.containsMouse ? Theme.primaryContainerHover : Theme.primaryContainer)
        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: mini.iconName
                iconSize: 18
                color: mini.danger ? Theme.errorColor : Theme.primaryText
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: mini.text
                color: mini.danger ? Theme.errorColor : Theme.primaryText
                font.pixelSize: Theme.fontLabel
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mini.clicked()
        }
    }

    Connections {
        target: root.controller
        function onCurrentProfileChanged() { root.reloadProfile() }
    }

    Component.onCompleted: reloadProfile()

    Rectangle {
        id: headerCard
        Layout.fillWidth: true
        Layout.preferredHeight: 68
        radius: Theme.radiusLarge
        color: Theme.surfaceContainerLow
        border.color: Theme.outlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.narrow ? 8 : 10
            spacing: root.narrow ? 6 : 12

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.narrow ? "当前方案" : "当前推送方案"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontComponentTitle
                font.weight: Font.DemiBold
            }

            Rectangle {
                readonly property bool successState: controller.status === "已保存"
                                                     || controller.status.indexOf("成功") >= 0
                readonly property bool errorState: controller.status.indexOf("失败") >= 0
                visible: !root.narrow
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 112
                Layout.minimumWidth: 112
                Layout.maximumWidth: 112
                Layout.preferredHeight: 34
                radius: Theme.radiusSmall
                color: successState ? Theme.successContainer
                                    : errorState ? Theme.errorContainer
                                    : Theme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: parent.parent.successState ? Theme.success
                                                       : parent.parent.errorState ? Theme.errorColor
                                                                                 : Theme.outline
                    }
                    Text {
                        id: statusText
                        Layout.fillWidth: true
                        text: controller.status
                        color: parent.parent.successState ? Theme.success
                                                        : parent.parent.errorState ? Theme.errorColor
                                                                                  : Theme.textSecondary
                        font.pixelSize: Theme.fontSupporting
                        elide: Text.ElideRight
                    }
                }
            }

            AppComboBox {
                id: profileSelector
                Layout.fillWidth: true
                Layout.minimumWidth: root.narrow ? 150 : 260
                Layout.alignment: Qt.AlignVCenter
                model: controller.profileNames
                currentIndex: controller.currentIndex
                onActivated: {
                    root.commitForm()
                    controller.selectProfile(currentIndex)
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: root.narrow ? 4 : 6
                MiniButton { implicitWidth: root.narrow ? 66 : 88; text: "新建"; iconName: "add"; onClicked: { root.commitForm(); controller.newProfile() } }
                MiniButton { implicitWidth: root.narrow ? 66 : 88; text: "复制"; iconName: "content_copy"; onClicked: { root.commitForm(); controller.duplicateProfile() } }
                MiniButton { implicitWidth: root.narrow ? 66 : 88; text: "删除"; iconName: "delete"; danger: true; onClicked: controller.deleteProfile() }
            }
        }
    }

    Item {
        id: configRegion
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Theme.radiusMedium
            color: Theme.surfaceContainerLow
            border.color: Theme.outlineVariant
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                FieldLabel { text: "方案名称" }
                AppField {
                    id: profileName
                    Layout.fillWidth: true
                    background: null
                    onTextEdited: controller.markCurrentProfileDirty()
                    onEditingFinished: controller.updateField("root", "name", text.trim())
                }
                Rectangle {
                    visible: !root.narrow
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    radius: 5
                    color: controller.scheduleRunning ? Theme.success : Theme.outline
                }
                Text {
                    visible: !root.narrow
                    text: controller.scheduleRunning ? "定时运行中" : "定时未启动"
                    color: controller.scheduleRunning ? Theme.success : Theme.textSecondary
                    font.pixelSize: Theme.fontSupporting
                }
            }
        }

        Rectangle {
            id: tabs
            property int currentIndex: 0
            Layout.preferredWidth: root.narrow ? 230 : 360
            Layout.preferredHeight: 42
            Layout.minimumHeight: 42
            Layout.maximumHeight: 42
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusMedium
            color: Theme.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Repeater {
                    model: ["Jira", "飞书", "定时"]
                    Rectangle {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: tabs.currentIndex === index ? Theme.primaryContainer : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: tabs.currentIndex === index ? Theme.primaryText : Theme.textSecondary
                            font.pixelSize: Theme.fontBody
                            font.weight: tabs.currentIndex === index ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tabs.currentIndex = index
                        }
                    }
                }
            }
        }
    }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                radius: Theme.radiusLarge
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant

                StackLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    currentIndex: tabs.currentIndex

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: jiraForm.implicitHeight
                ScrollBar.vertical: ScrollBar { }
                ColumnLayout {
                    id: jiraForm
                    width: parent.width
                    spacing: 12
                    Text { text: "Jira 数据源"; color: Theme.textPrimary; font.pixelSize: Theme.fontSectionTitle; font.weight: Font.DemiBold }
                    Text { text: "使用 JQL 获取议题与变更记录，Token 仅保存在本机。"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrow ? 1 : 3
                        columnSpacing: 14
                        rowSpacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            FieldLabel { text: "Jira 地址 *" }
                            AppField { id: jiraUrl; placeholderText: "https://jira.example.com"; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("jira", "base_url", text.trim()) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            FieldLabel { text: "Token / PAT *" }
                            AppField { id: jiraToken; echoMode: TextInput.Password; placeholderText: "输入访问令牌"; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("jira", "token", text) }
                        }
                        ColumnLayout {
                            spacing: 5
                            FieldLabel { text: "最多获取数" }
                            SpinBox {
                                id: jiraMax
                                Layout.preferredWidth: 240; Layout.preferredHeight: 46
                                from: 1; to: 1000; editable: true
                                onValueModified: controller.updateField("jira", "max_results", value)
                            }
                        }
                    }
                    FieldLabel { text: "JQL 查询 *" }
                    TextArea {
                        id: jiraJql
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
                        color: Theme.textPrimary
                        font.family: "Cascadia Mono"
                        font.pixelSize: Theme.fontCode
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        placeholderText: "status != Done ORDER BY assignee ASC, priority DESC"
                        onTextChanged: if (activeFocus) controller.markCurrentProfileDirty()
                        onActiveFocusChanged: if (!activeFocus) controller.updateField("jira", "jql_filter", text)
                        background: Rectangle { radius: Theme.radiusMedium; color: Theme.surface; border.color: parent.activeFocus ? Theme.primary : Theme.outline; border.width: parent.activeFocus ? 2 : 1 }
                    }
                    Item { Layout.preferredHeight: 2 }
                }
            }

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: feishuForm.implicitHeight
                ScrollBar.vertical: ScrollBar { }
                ColumnLayout {
                    id: feishuForm
                    width: parent.width
                    spacing: 12
                    Text { text: "飞书机器人"; color: Theme.textPrimary; font.pixelSize: Theme.fontSectionTitle; font.weight: Font.DemiBold }
                    Text { text: "配置群机器人安全校验；自建应用凭据仅用于将邮箱解析为 open_id。"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrow ? 1 : 2
                        columnSpacing: 14; rowSpacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "Webhook URL *" }
                            AppField { id: webhook; placeholderText: "https://open.feishu.cn/open-apis/bot/v2/hook/..."; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("feishu", "webhook_url", text.trim()) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "安全关键词" }
                            AppField { id: keyword; placeholderText: "与机器人安全设置保持一致"; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("feishu", "keyword", text.trim()) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "签名 Secret（可选）" }
                            AppField { id: signSecret; echoMode: TextInput.Password; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("feishu", "secret", text) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "邮箱域名" }
                            AppField { id: emailDomain; placeholderText: "@geely.com"; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("message", "email_domain", text.trim() || "@geely.com") }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "App ID（可选）" }
                            AppField { id: appId; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("feishu", "app_id", text.trim()) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            FieldLabel { text: "App Secret（可选）" }
                            AppField { id: appSecret; echoMode: TextInput.Password; onTextEdited: controller.markCurrentProfileDirty(); onEditingFinished: controller.updateField("feishu", "app_secret", text) }
                        }
                    }
                    CheckBox {
                        id: atAssignee
                        text: "在消息中 @ 负责人（需要有效 open_id）"
                        checked: true
                        palette.text: Theme.textPrimary
                        onToggled: controller.updateField("message", "at_assignee", checked)
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 54; radius: Theme.radiusMedium; color: Theme.tealContainer
                        RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 10
                            MaterialIcon { icon: "info"; iconSize: 20; color: Theme.teal }
                            Text { Layout.fillWidth: true; text: "未解析到 open_id 时只显示负责人姓名，不会发送无效 @。"; color: Theme.teal; font.pixelSize: Theme.fontSupporting; wrapMode: Text.WordWrap }
                        }
                    }
                    Item { Layout.preferredHeight: 2 }
                }
            }

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: scheduleForm.implicitHeight
                ScrollBar.vertical: ScrollBar { }
                ColumnLayout {
                    id: scheduleForm
                    width: parent.width
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 3
                            Text { text: "定时推送"; color: Theme.textPrimary; font.pixelSize: Theme.fontSectionTitle; font.weight: Font.DemiBold }
                            Text { text: "应用运行期间，每 30 秒检查一次到点方案。"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
                        }
                        Switch {
                            id: scheduleEnabled
                            text: checked ? "已启用" : "未启用"
                            palette.text: Theme.textPrimary
                            onToggled: controller.updateField("schedule", "enabled", checked)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrow ? 1 : 2
                        columnSpacing: 14; rowSpacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            FieldLabel { text: "触发方式" }
                            AppComboBox {
                                id: scheduleMode
                                Layout.fillWidth: true
                                model: ["按间隔", "每日定点"]
                                onActivated: controller.updateField("schedule", "mode", currentIndex === 0 ? "interval" : "daily")
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            FieldLabel { text: "间隔分钟数" }
                            SpinBox {
                                id: intervalMinutes
                                Layout.fillWidth: true; Layout.preferredHeight: 46
                                from: 1; to: 1440; editable: true
                                enabled: scheduleMode.currentIndex === 0
                                onValueModified: controller.updateField("schedule", "interval_minutes", value)
                            }
                        }
                    }
                    FieldLabel { text: "每日推送时间" }
                    AppField {
                        id: dailyTimes
                        enabled: scheduleMode.currentIndex === 1
                        placeholderText: "09:00,15:00,18:00"
                        onTextEdited: controller.markCurrentProfileDirty()
                        onEditingFinished: controller.updateDailyTimes(text)
                    }
                    Text { text: "多个时刻使用逗号分隔；每个时刻当天只触发一次。"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 76; radius: Theme.radiusMedium; color: Theme.surface
                        border.color: Theme.outlineVariant
                        RowLayout { anchors.fill: parent; anchors.margins: 14; spacing: 12
                            MaterialIcon { icon: controller.scheduleRunning ? "schedule" : "schedule_send"; iconSize: 26; color: controller.scheduleRunning ? Theme.success : Theme.textSecondary }
                            ColumnLayout { Layout.fillWidth: true; spacing: 2
                                Text { text: controller.scheduleRunning ? "调度器正在运行" : "调度器尚未启动"; color: Theme.textPrimary; font.pixelSize: Theme.fontComponentTitle; font.weight: Font.DemiBold }
                                Text { text: "启动后会同时管理所有已启用的推送方案"; color: Theme.textSecondary; font.pixelSize: Theme.fontSupporting }
                            }
                            MiniButton { text: "启动"; iconName: "play_arrow"; visible: !controller.scheduleRunning; onClicked: { root.commitForm(); controller.startSchedule() } }
                            MiniButton { text: "全部停止"; iconName: "stop"; danger: true; visible: controller.scheduleRunning; onClicked: controller.stopSchedule() }
                        }
                    }
                    Item { Layout.preferredHeight: 2 }
                }
            }
                }
            }
        }
    }

    Item {
        id: outputPanel
        Layout.fillWidth: true
        Layout.preferredHeight: root.outputPanelCollapsedHeight
        Layout.minimumHeight: root.outputPanelCollapsedHeight
        Layout.maximumHeight: root.outputPanelCollapsedHeight
        z: 10

        Rectangle {
            id: outputDrawer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.outputPanelCollapsedHeight
                    + root.outputLogMaxHeight * root.outputReveal
            color: Theme.surface

        Item {
            id: outputToggle
            objectName: "jiraFeishuOutputToggle"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 10

            Rectangle {
                anchors.centerIn: parent
                width: 52
                height: 4
                radius: 2
                color: outputToggleArea.containsMouse ? Theme.primary : Theme.outline
            }

            MouseArea {
                id: outputToggleArea
                anchors.centerIn: parent
                width: 96
                height: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.outputExpanded = !root.outputExpanded
            }

            ToolTip.visible: outputToggleArea.containsMouse
            ToolTip.text: root.outputExpanded ? "隐藏运行记录" : "显示运行记录"
            ToolTip.delay: 450
        }

        RowLayout {
            id: actionRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: outputToggle.bottom
            anchors.topMargin: 6
            height: 44
            spacing: 10
            PrimaryButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 150
                implicitHeight: 44
                text: root.narrow ? "测试" : "测试连接"
                iconName: "lan"
                tonal: true
                enabled: !controller.busy
                onClicked: root.runCurrent("test")
            }
            PrimaryButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 150
                implicitHeight: 44
                text: root.narrow ? "预览" : "预览消息"
                iconName: "preview"
                tonal: true
                enabled: !controller.busy
                onClicked: root.runCurrent("dry")
            }
            PrimaryButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 150
                implicitHeight: 44
                text: root.narrow ? "保存" : "保存配置"
                iconName: "save"
                tonal: true
                onClicked: {
                    root.commitForm()
                    controller.saveProfiles()
                }
            }
            PrimaryButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 150
                implicitHeight: 44
                text: controller.busy ? "处理中" : (root.narrow ? "推送" : "立即推送")
                iconName: controller.busy ? "hourglass_top" : "send"
                enabled: !controller.busy
                onClicked: root.runCurrent("push")
            }
        }

        Rectangle {
            id: outputLog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: actionRow.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            radius: Theme.radiusLarge
            color: Theme.consoleBackground
            border.color: Theme.outlineVariant
            clip: true
            visible: height > 0
            opacity: root.outputReveal
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; Layout.leftMargin: 12; Layout.rightMargin: 8
                    Text { text: "运行记录"; color: Theme.consoleText; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    MiniButton { text: "清空"; iconName: "delete_sweep"; implicitWidth: 78; implicitHeight: 30; onClicked: controller.clearLog() }
                }
                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    TextArea {
                        text: controller.logText
                        readOnly: true
                        selectByMouse: true
                        color: Theme.consoleText
                        font.family: "Cascadia Mono"
                        font.pixelSize: Theme.fontCaption
                        wrapMode: TextEdit.Wrap
                        background: null
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
        }
    }
}
