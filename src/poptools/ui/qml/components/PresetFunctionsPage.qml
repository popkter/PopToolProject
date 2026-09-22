pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    required property var controller
    required property var parentWindow
    required property var parameterValues
    required property var presetUtilities
    required property var androidBackend
    required property var jiraFeishuBackend
    property string searchQuery: ""
    property bool compact: false
    property bool compactHeight: false
    property bool compactToolList: false
    property bool overlaysVisible: false
    property real toolListWidth: 288
    property real categoryListHeight: 0
    property int selectedCategory: 0
    property bool showHiddenCategories: false
    property string contextCategoryTag: ""

    signal searchEdited(string query)
    signal confirmRunRequested(var values)

    color: Theme.darkMode ? Theme.surface : "#FBFCFE"

    readonly property var categories: [
        { title: "模拟相关", subtitle: "文本、按键与触控", icon: "touch_app", tag: "模拟相关", count: 7 },
        { title: "环境相关", subtitle: "ADB 与 Fastboot 环境", icon: "terminal", tag: "环境相关", count: 4 },
        { title: "硬件相关", subtitle: "设备电源控制", icon: "power_settings_new", tag: "硬件相关", count: 2 },
        { title: "跳转相关", subtitle: "URL、Activity 与设置", icon: "open_in_new", tag: "跳转相关", count: 4 },
        { title: "其他设备操作", subtitle: "应用、文件、日志与网络", icon: "build", tag: "其他设备操作", count: 24 },
        { title: "其他预设", subtitle: "投屏、录制与实用工具", icon: "widgets", tag: "其他预设", count: 4 }
    ]
    readonly property bool hasHiddenCategories: root.controller.hiddenPresetCategories
        && root.controller.hiddenPresetCategories.length > 0
    readonly property var visibleCategories: root.showHiddenCategories
        ? root.categories
        : root.categories.filter(function(category) {
            return root.controller.hiddenPresetCategories.indexOf(category.tag) < 0
        })
    readonly property string activeCategoryTag:
        visibleCategories[selectedCategory] ? visibleCategories[selectedCategory].tag : ""
    readonly property string selectedPresetCommand:
        root.controller.selectedTool && root.controller.selectedTool.executor
            ? root.controller.selectedTool.executor.command : ""
    readonly property bool usesDedicatedWorkspace:
        ["scrcpy", "recording", "jira_feishu", "colors"].indexOf(
            root.selectedPresetCommand) >= 0

    function belongsToCategory(tags) {
        const values = tags || []
        if (activeCategoryTag === "其他预设") {
            const imported = ["模拟相关", "环境相关", "硬件相关", "跳转相关", "其他设备操作"]
            for (let index = 0; index < imported.length; index++) {
                if (values.indexOf(imported[index]) >= 0)
                    return false
            }
            return true
        }
        return values.indexOf(activeCategoryTag) >= 0
    }

    function selectCategory(index) {
        selectedCategory = index
        controller.selectFirstPresetInCategory(visibleCategories[index].tag)
        toolList.positionViewAtBeginning()
    }

    function syncCategoryForSelectedTool() {
        const tags = controller.selectedTool.tags || []
        for (let index = 0; index < visibleCategories.length; index++) {
            if (tags.indexOf(visibleCategories[index].tag) >= 0) {
                selectedCategory = index
                return
            }
        }
        selectedCategory = Math.max(0, visibleCategories.length - 1)
    }

    function hideCategory(tag) {
        if (visibleCategories.length <= 1)
            return
        controller.setPresetCategoryHidden(tag, true)
        if (activeCategoryTag === tag && !root.showHiddenCategories) {
            selectedCategory = 0
            controller.selectFirstPresetInCategory(visibleCategories[0].tag)
        }
    }

    function toggleCategoryHidden(tag) {
        const hidden = root.controller.hiddenPresetCategories.indexOf(tag) >= 0
        if (hidden) {
            root.controller.setPresetCategoryHidden(tag, false)
            return
        }
        root.hideCategory(tag)
    }

    function ensureSelectedCategoryVisible() {
        if (visibleCategories.length === 0)
            return
        if (selectedCategory >= visibleCategories.length) {
            selectedCategory = 0
            controller.selectFirstPresetInCategory(visibleCategories[0].tag)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space28
        anchors.rightMargin: Theme.space28
        anchors.bottomMargin: Theme.space28
        spacing: Theme.space16

        WorkspacePageHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.pageHeaderHeight
            Layout.minimumHeight: Theme.pageHeaderHeight
            Layout.maximumHeight: Theme.pageHeaderHeight
            title: "预设"
            description: "快速调用常用 Android 调试功能"
            titlePixelSize: Theme.workspaceTitleSize
            actionWidth: Math.min(390, root.width * 0.38)

            AppTextField {
                Layout.preferredWidth: Math.min(390, root.width * 0.38)
                Layout.preferredHeight: 40
                leftPadding: 40
                rightPadding: 14
                placeholderText: "搜索预设名称或描述..."
                text: root.searchQuery
                color: Theme.textPrimary
                onTextChanged: if (root.searchQuery !== text) root.searchEdited(text)
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.surfaceContainerLow
                    border.color: parent.activeFocus ? Theme.primary : Theme.outline
                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "search"
                        iconSize: 19
                        color: Theme.textSecondary
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space16

            Rectangle {
                Layout.preferredWidth: root.toolListWidth
                Layout.minimumWidth: 250
                Layout.maximumWidth: Math.max(250, root.width * 0.46)
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant
                border.width: Theme.borderWidthThin
                clip: true

                ColumnLayout {
                    id: categoryPaneLayout
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space8
                        Text {
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            text: "功能分类"
                            color: Theme.textSecondary
                        }
                        Text {
                            visible: root.hasHiddenCategories
                            text: "显示全部"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontLabel
                        }
                        ToggleControl {
                            visible: root.hasHiddenCategories
                            checked: root.showHiddenCategories
                            onToggled: function(value) { root.showHiddenCategories = value }
                        }
                    }

                    ListView {
                        id: categoryList
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.categoryListHeight > 0
                            ? root.categoryListHeight
                            : Math.min(contentHeight, parent.height * 0.52)
                        model: root.visibleCategories
                        spacing: Theme.space4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            id: categoryScrollBar
                            policy: categoryList.contentHeight > categoryList.height + 0.5
                                ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        }

                        delegate: Rectangle {
                            id: categoryRow
                            required property var modelData
                            required property int index
                            readonly property bool hiddenCategory:
                                root.controller.hiddenPresetCategories.indexOf(
                                    categoryRow.modelData.tag) >= 0
                            width: categoryList.width - (categoryScrollBar.visible
                                ? categoryScrollBar.width + Theme.space8 : 0)
                            height: 54
                            radius: Theme.radiusSmall
                            color: root.selectedCategory === index
                                ? Theme.primaryContainer
                                : (categoryMouse.containsMouse ? Theme.surfaceContainer : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space8
                                anchors.rightMargin: Theme.space8
                                spacing: Theme.space12
                                MaterialIcon {
                                    icon: categoryRow.modelData.icon
                                    iconSize: 21
                                    color: categoryRow.hiddenCategory
                                        ? Theme.textSecondary
                                        : root.selectedCategory === categoryRow.index
                                            ? Theme.primary : Theme.secondary
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: categoryRow.modelData.title
                                        color: categoryRow.hiddenCategory
                                            ? Theme.textSecondary : Theme.textPrimary
                                        font.pixelSize: Theme.fontBody
                                        font.weight: categoryRow.hiddenCategory
                                            ? Font.Normal : Font.DemiBold
                                    }
                                    Text { Layout.fillWidth: true; text: categoryRow.modelData.subtitle; color: Theme.textSecondary; font.pixelSize: Theme.fontMicro; elide: Text.ElideRight }
                                }
                                Text {
                                    text: categoryRow.modelData.count
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            MouseArea {
                                id: categoryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectCategory(categoryRow.index)
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                preventStealing: true
                                z: 2
                                onClicked: function(mouse) {
                                    root.contextCategoryTag = categoryRow.modelData.tag
                                    const point = categoryRow.mapToItem(root, mouse.x, mouse.y)
                                    categoryContextMenu.x = Math.round(point.x)
                                    categoryContextMenu.y = Math.round(point.y)
                                    categoryContextMenu.open()
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: categoryDivider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        color: Theme.surfaceContainerLow
                        z: 2

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: Theme.outlineVariant
                        }

                        MouseArea {
                            id: categoryDividerMouse
                            anchors.fill: parent
                            cursorShape: Qt.SizeVerCursor
                            property real startHeight: 0
                            property real startPointerY: 0

                            onPressed: {
                                startHeight = categoryList.height
                                startPointerY = categoryDivider.mapToItem(
                                    categoryPaneLayout, mouse.x, mouse.y).y
                            }
                            onPositionChanged: {
                                if (!pressed)
                                    return

                                const pointerY = categoryDivider.mapToItem(
                                    categoryPaneLayout, mouse.x, mouse.y).y
                                const minimumCategoryHeight = Math.min(
                                    54, categoryList.contentHeight
                                )
                                const minimumToolHeight = 120
                                const maximumCategoryHeight = Math.max(
                                    minimumCategoryHeight,
                                    categoryPaneLayout.height - categoryList.y
                                        - minimumToolHeight
                                )
                                root.categoryListHeight = Math.max(
                                    minimumCategoryHeight,
                                    Math.min(
                                        maximumCategoryHeight,
                                        startHeight + pointerY - startPointerY
                                    )
                                )
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space8
                        text: root.visibleCategories.length > 0
                            ? root.visibleCategories[root.selectedCategory].title
                                + "（" + root.visibleCategories[root.selectedCategory].count + "）"
                            : "暂无可见分类"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        id: toolList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.controller.toolsModel
                        spacing: Theme.space4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            id: toolRow
                            required property string toolId
                            required property string title
                            required property string description
                            required property string iconName
                            required property bool selected
                            width: toolList.width - 8
                            height: 56
                            radius: Theme.radiusSmall
                            color: selected ? Theme.primaryContainer
                                : (toolMouse.containsMouse ? Theme.surfaceContainer : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space8
                                anchors.rightMargin: Theme.space8
                                spacing: Theme.space12
                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusSmall
                                    color: Theme.surface
                                    MaterialIcon { anchors.centerIn: parent; icon: toolRow.iconName || "terminal"; iconSize: 19; color: toolRow.selected ? Theme.primary : Theme.secondary }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text { Layout.fillWidth: true; text: toolRow.title; color: toolRow.selected ? Theme.primary : Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: toolRow.selected ? Font.Bold : Font.Normal; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: toolRow.description; color: Theme.textSecondary; font.pixelSize: Theme.fontMicro; elide: Text.ElideRight }
                                }
                                MaterialIcon { icon: "chevron_right"; iconSize: 18; color: toolRow.selected ? Theme.primary : Theme.textSecondary }
                            }

                            MouseArea {
                                id: toolMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.controller.selectTool(toolRow.toolId)
                            }
                        }
                    }
                }
            }

            Loader {
                id: detailWorkspaceLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: root.usesDedicatedWorkspace
                    ? dedicatedWorkspace
                    : standardWorkspace
            }
        }
    }

    Component {
        id: standardWorkspace
        CustomToolDetailPanel {
            controller: root.controller
            androidBackend: root.androidBackend
            parentWindow: root.parentWindow
            parameterValues: root.parameterValues
            displayedTool: root.controller.selectedTool
            allowManagement: false
            onConfirmRunRequested: function(values) { root.confirmRunRequested(values) }
        }
    }

    AppMenu {
        id: categoryContextMenu
        AppMenuItem {
            readonly property bool categoryHidden:
                root.controller.hiddenPresetCategories.indexOf(root.contextCategoryTag) >= 0
            text: categoryHidden
                ? "取消隐藏“" + root.contextCategoryTag + "”分类"
                : "隐藏“" + root.contextCategoryTag + "”分类"
            enabled: categoryHidden || root.visibleCategories.length > 1
            onTriggered: root.toggleCategoryHidden(root.contextCategoryTag)
        }
    }

    Component {
        id: dedicatedWorkspace
        Item {
            anchors.fill: parent

            CommandWorkspace {
                anchors.fill: parent
                visible: root.selectedPresetCommand === "scrcpy"
                controller: root.controller
                parentWindow: root.parentWindow
                parameterValues: root.parameterValues
                androidController: root.androidBackend
                scrcpySelected: true
                overlaysVisible: root.overlaysVisible
            }

            PresetWorkspace {
                anchors.fill: parent
                visible: root.selectedPresetCommand !== "scrcpy"
                toolController: root.controller
                utilities: root.presetUtilities
                androidBackend: root.androidBackend
                jiraFeishuBackend: root.jiraFeishuBackend
                compact: root.compact
            }
        }
    }

    Connections {
        target: root.controller
        function onSelectedToolChanged() {
            root.syncCategoryForSelectedTool()
            root.controller.setPresetCategory(root.activeCategoryTag)
        }
        function onHiddenPresetCategoriesChanged() {
            root.ensureSelectedCategoryVisible()
        }
    }

    Component.onCompleted: {
        if (root.visibleCategories.length > 0) {
            root.selectedCategory = 0
            root.controller.selectFirstPresetInCategory(root.visibleCategories[0].tag)
        }
    }
}
