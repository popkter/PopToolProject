import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "theme"

ApplicationWindow {
    id: window
    width: 800
    height: 600
    minimumWidth: 720
    minimumHeight: 448
    visible: true
    title: "泡泡工具箱"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: Theme.surface
    palette.window: Theme.surface
    palette.windowText: Theme.textPrimary
    palette.base: Theme.surfaceContainerLow
    palette.text: Theme.textPrimary
    palette.button: Theme.surfaceContainer
    palette.buttonText: Theme.textPrimary
    palette.highlight: Theme.primary
    palette.highlightedText: Theme.primaryForeground
    palette.placeholderText: Theme.textSecondary

    Binding {
        target: Theme
        property: "darkMode"
        value: settingsController.darkTheme
    }

    property var parameterValues: ({})
    property string toolSearchQuery: ""
    property real primaryNavWidth: 86
    property real toolListWidth: 120
    property bool standbySelected: false
    property string standbyDateTime: formatStandbyDateTime(new Date())
    readonly property real minimumPrimaryNavWidth: 76
    readonly property real minimumToolListWidth: 120
    readonly property real minimumContentWidth: 320
    readonly property bool compactPrimaryNav: primaryNavWidth < 176
    readonly property bool compactToolList: toolListWidth < 190
    readonly property bool compactContentActions: width < 760
    readonly property bool compactHeight: height < 620
    readonly property bool scrcpySelected:
        appController.selectedTool.workspace === "scrcpy"

    readonly property bool internalPresetSelected:
        !standbySelected
        && appController.section === "preset"
        && appController.selectedTool.workspace === "preset"

    function formatStandbyDateTime(date) {
        const weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        function pad(value) { return value < 10 ? "0" + value : String(value) }
        return date.getFullYear() + "年"
                + (date.getMonth() + 1) + "月"
                + date.getDate() + "日"
                + weekdays[date.getDay()] + " "
                + pad(date.getHours()) + ":"
                + pad(date.getMinutes()) + ":"
                + pad(date.getSeconds())
    }

    function clampPanelWidths() {
        primaryNavWidth = Math.max(minimumPrimaryNavWidth,
                                   Math.min(primaryNavWidth,
                                            width - minimumToolListWidth - minimumContentWidth))
        toolListWidth = Math.max(minimumToolListWidth,
                                 Math.min(toolListWidth,
                                          width - primaryNavWidth - minimumContentWidth))
    }

    onWidthChanged: clampPanelWidths()
    onClosing: function(close) {
        if (trayController.available && !trayController.quitting) {
            close.accepted = false
            window.hide()
            trayController.notify_hidden()
        }
    }

    function resetParameters() {
        var values = {}
        var tool = appController.selectedTool
        var parameters = tool.parameters || []
        for (var i = 0; i < parameters.length; i++)
            values[parameters[i].id] = parameters[i].default
        parameterValues = values
    }

    function hideScrcpyWindow() {
        appController.updateScrcpyGeometry(0, 0, 0, 0, false)
    }

    onScrcpySelectedChanged: {
        if (!scrcpySelected)
            hideScrcpyWindow()
    }
    onStandbySelectedChanged: {
        if (!scrcpySelected || standbySelected)
            hideScrcpyWindow()
    }
    onVisibleChanged: {
        if (!visible)
            hideScrcpyWindow()
    }

    Connections {
        target: appController
        function onSelectedToolChanged() {
            window.resetParameters()
            if (!window.scrcpySelected)
                window.hideScrcpyWindow()
        }
        function onPythonDoctorWarning(message) {
            pythonDoctorDialog.message = message
            Qt.callLater(function() { pythonDoctorDialog.open() })
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: window.standbySelected
        triggeredOnStart: true
        onTriggered: window.standbyDateTime = window.formatStandbyDateTime(new Date())
    }

    Component.onCompleted: {
        width = settingsController.startupWindowWidth
        height = Math.max(minimumHeight, settingsController.startupWindowHeight)
        primaryNavWidth = width < 1180 ? 86 : 262
        toolListWidth = width < 900 ? minimumToolListWidth : 286
        clampPanelWidths()
        if (settingsController.startupWindowCentered) {
            x = Screen.virtualX + Math.round((Screen.width - width) / 2)
            y = Screen.virtualY + Math.round((Screen.height - height) / 2)
        }
        resetParameters()
    }

    component ResizeHandle: MouseArea {
        required property int resizeEdges
        visible: window.visibility !== Window.Maximized
        z: 1000
        onPressed: window.startSystemResize(resizeEdges)
    }

    ResizeHandle {
        resizeEdges: Qt.LeftEdge
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 6
        cursorShape: Qt.SizeHorCursor
    }
    ResizeHandle {
        resizeEdges: Qt.RightEdge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 6
        cursorShape: Qt.SizeHorCursor
    }
    ResizeHandle {
        resizeEdges: Qt.TopEdge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 6
        cursorShape: Qt.SizeVerCursor
    }
    ResizeHandle {
        resizeEdges: Qt.BottomEdge
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 6
        cursorShape: Qt.SizeVerCursor
    }
    ResizeHandle {
        resizeEdges: Qt.TopEdge | Qt.LeftEdge
        anchors.top: parent.top
        anchors.left: parent.left
        width: 8
        height: 8
        cursorShape: Qt.SizeFDiagCursor
    }
    ResizeHandle {
        resizeEdges: Qt.TopEdge | Qt.RightEdge
        anchors.top: parent.top
        anchors.right: parent.right
        width: 8
        height: 8
        cursorShape: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        resizeEdges: Qt.BottomEdge | Qt.LeftEdge
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 8
        height: 8
        cursorShape: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        resizeEdges: Qt.BottomEdge | Qt.RightEdge
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 8
        height: 8
        cursorShape: Qt.SizeFDiagCursor
    }

    Rectangle {
        id: middlePanelBackdrop
        x: window.primaryNavWidth
        width: window.toolListWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: !window.standbySelected
        color: settingsController.middlePanelColor === "#EEF7FF"
               ? Theme.middlePanel : settingsController.middlePanelColor
    }

    Rectangle {
        id: customTitleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        color: "transparent"
        z: 900

        MouseArea {
            anchors.left: parent.left
            anchors.right: windowButtons.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            onPressed: window.startSystemMove()
            onDoubleClicked: {
                if (window.visibility === Window.Maximized)
                    window.showNormal()
                else
                    window.showMaximized()
            }
        }

        RowLayout {
            id: windowButtons
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 46
                Layout.fillHeight: true
                color: minimizeArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                MaterialIcon { anchors.centerIn: parent; icon: "remove"; iconSize: 19; color: Theme.textPrimary }
                MouseArea { id: minimizeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.showMinimized() }
            }
            Rectangle {
                Layout.preferredWidth: 46
                Layout.fillHeight: true
                color: maximizeArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: window.visibility === Window.Maximized ? "filter_none" : "crop_square"
                    iconSize: 17
                    color: Theme.textPrimary
                }
                MouseArea {
                    id: maximizeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (window.visibility === Window.Maximized)
                            window.showNormal()
                        else
                            window.showMaximized()
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 46
                Layout.fillHeight: true
                color: closeArea.containsMouse ? "#C42B1C" : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "close"
                    iconSize: 19
                    color: closeArea.containsMouse ? "white" : Theme.textPrimary
                }
                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.close() }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: window.visibility === Window.Maximized ? 0 : 10
        border.width: 1
        border.color: Theme.outlineVariant
        z: 950
        enabled: false
    }

    RowLayout {
        anchors.top: customTitleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        Rectangle {
            Layout.preferredWidth: window.primaryNavWidth
            Layout.fillHeight: true
            color: Theme.surface
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: window.compactHeight || window.compactPrimaryNav ? 10 : 18
                anchors.rightMargin: window.compactHeight || window.compactPrimaryNav ? 10 : 18
                anchors.topMargin: window.compactHeight ? 10 : 18
                anchors.bottomMargin: window.compactHeight ? 10 : 18
                spacing: window.compactHeight ? 4 : 7

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.compactHeight ? 74 : 112
                    spacing: window.compactPrimaryNav ? 0 : 14
                    clip: true

                    Image {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        source: Qt.resolvedUrl("../../resources/icons/app-icon.png")
                        sourceSize.width: 116
                        sourceSize.height: 116
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    ColumnLayout {
                        visible: !window.compactPrimaryNav
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "泡泡工具箱"
                            color: Theme.textPrimary
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Android 开发者工具箱"
                            color: Theme.textSecondary
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }

                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "客制功能"
                    iconName: "home"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.standbySelected && appController.section === "custom"
                    onClicked: {
                        window.standbySelected = false
                        appController.navigate("custom")
                    }
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "预设功能"
                    iconName: "language"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.standbySelected && appController.section === "preset"
                    onClicked: {
                        window.standbySelected = false
                        appController.navigate("preset")
                    }
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "待机工具"
                    iconName: "schedule"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: window.standbySelected
                    onClicked: window.standbySelected = true
                }



                Item { Layout.fillHeight: true }

                DeviceSelector {
                    id: globalDeviceSelector
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    controller: androidController
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                }

                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "设置"
                    iconName: "settings"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: false
                    onClicked: settingsDialog.open()
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: window.toolListWidth
            Layout.fillHeight: true
            visible: !window.standbySelected
            color: "transparent"
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: window.compactToolList || window.compactHeight ? 10 : 16
                anchors.rightMargin: window.compactToolList || window.compactHeight ? 10 : 16
                anchors.topMargin: window.compactHeight ? 10 : 16
                anchors.bottomMargin: window.compactHeight ? 10 : 16
                spacing: window.compactHeight ? 7 : 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.compactHeight ? 42 : 48
                    clip: true
                    Item { visible: window.compactToolList; Layout.fillWidth: true }
                    Text {
                        visible: !window.compactToolList
                        text: appController.sectionTitle
                        color: Theme.textPrimary
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                    }

                    ToolSortButton {
                        Layout.preferredWidth: 40
                        Layout.minimumWidth: 40
                        visible: appController.section === "custom"
                        controller: appController
                    }
                    Rectangle {
                        id: createCommandButton
                        visible: appController.section === "custom"
                        Layout.preferredWidth: 40
                        Layout.minimumWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: createCommandMouse.containsMouse
                               ? Theme.primaryContainerHover : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "add"
                            iconSize: 26
                            color: Theme.primary
                        }

                        ToolTip.visible: createCommandMouse.containsMouse
                        ToolTip.text: "新建命令"
                        ToolTip.delay: 450

                        MouseArea {
                            id: createCommandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: commandEditorDialog.openForCreate()
                        }
                    }
                    Item { visible: window.compactToolList; Layout.fillWidth: true }
                }

                Item {
                    id: compactSearchSlot
                    visible: window.compactToolList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.minimumHeight: 48
                    Layout.maximumHeight: 48

                    Rectangle {
                        id: compactSearchButton
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        radius: 24
                        color: compactSearchMouse.containsMouse
                               ? Theme.primaryContainerHover : Theme.surface

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "search"
                            iconSize: 24
                            color: Theme.primary
                        }

                        ToolTip.visible: compactSearchMouse.containsMouse
                        ToolTip.text: "搜索工具"
                        ToolTip.delay: 450

                        MouseArea {
                            id: compactSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var point = compactSearchButton.mapToItem(
                                            Overlay.overlay,
                                            compactSearchButton.width / 2,
                                            compactSearchButton.height + 8)
                                compactSearchPopup.x = Math.max(
                                            12,
                                            Math.min(point.x - compactSearchPopup.width / 2,
                                                     Overlay.overlay.width
                                                     - compactSearchPopup.width - 12))
                                compactSearchPopup.y = Math.max(
                                            12,
                                            Math.min(point.y,
                                                     Overlay.overlay.height
                                                     - compactSearchPopup.height - 12))
                                compactSearchPopup.open()
                                Qt.callLater(function() {
                                    compactSearchField.forceActiveFocus()
                                    compactSearchField.selectAll()
                                })
                            }
                        }
                    }
                }

                TextField {
                    id: searchField
                    visible: !window.compactToolList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.minimumHeight: 48
                    Layout.maximumHeight: 48
                    leftPadding: 44
                    rightPadding: 14
                    placeholderText: "搜索工具"
                    text: window.toolSearchQuery
                    color: Theme.textPrimary
                    font.pixelSize: 15
                    onTextChanged: {
                        if (window.toolSearchQuery !== text)
                            window.toolSearchQuery = text
                    }
                    background: Rectangle {
                        radius: 24
                        color: Theme.surface
                        border.color: searchField.activeFocus ? Theme.primary : Theme.outline
                        border.width: searchField.activeFocus ? 2 : 1
                        MaterialIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "search"
                            iconSize: 22
                            color: Theme.textSecondary
                        }
                    }
                }

                Popup {
                    id: compactSearchPopup
                    parent: Overlay.overlay
                    width: Math.min(320, Overlay.overlay.width - 24)
                    height: 68
                    padding: 10
                    modal: false
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: AppPopupSurface { }

                    contentItem: TextField {
                        id: compactSearchField
                        placeholderText: "搜索工具"
                        text: window.toolSearchQuery
                        leftPadding: 42
                        rightPadding: 14
                        color: Theme.textPrimary
                        font.pixelSize: 15
                        onTextChanged: {
                            if (window.toolSearchQuery !== text)
                                window.toolSearchQuery = text
                        }
                        background: Rectangle {
                            radius: 24
                            color: Theme.surface
                            border.color: compactSearchField.activeFocus
                                          ? Theme.primary : Theme.outline
                            border.width: compactSearchField.activeFocus ? 2 : 1
                            MaterialIcon {
                                anchors.left: parent.left
                                anchors.leftMargin: 13
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "search"
                                iconSize: 21
                                color: Theme.textSecondary
                            }
                        }
                    }
                }


                ListView {
                    id: toolList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5
                    model: appController.toolsModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: toolDelegate
                        required property int index
                        required property string toolId
                        required property string title
                        required property string iconName
                        required property bool selected
                        property bool matches: window.toolSearchQuery.length === 0
                                               || title.toLowerCase().indexOf(window.toolSearchQuery.toLowerCase()) >= 0
                        width: toolList.width
                        height: matches ? 64 : 0
                        visible: matches
                        ToolListItem {
                            anchors.fill: parent
                            title: parent.title
                            iconName: parent.iconName
                            selected: parent.selected
                            compact: window.compactToolList
                            draggable: appController.section === "custom"
                                       && appController.toolSortMode === "custom"
                                       && window.toolSearchQuery.length === 0
                            dragTarget: toolDelegate
                            dragMinimumY: 0
                            dragMaximumY: Math.max(0, toolList.contentHeight - toolDelegate.height)
                            onClicked: appController.selectTool(parent.toolId)
                            onDragFinished: function(centerY) {
                                var rowHeight = 64 + toolList.spacing
                                var targetIndex = Math.max(0, Math.min(toolList.count - 1,
                                                                       Math.floor(centerY / rowHeight)))
                                appController.moveTool(parent.toolId, targetIndex)
                            }
                        }
                    }
                }

            }
        }

        Rectangle {
            id: contentPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface

            Text {
                anchors.centerIn: parent
                visible: window.standbySelected
                text: window.standbyDateTime
                color: Theme.textPrimary
                font.pixelSize: window.compactContentActions ? 28 : 40
                font.weight: Font.DemiBold
            }

            ColumnLayout {
                id: contentLayout
                visible: !window.standbySelected
                anchors.fill: parent
                anchors.leftMargin: window.compactContentActions ? 12 : 32
                anchors.rightMargin: window.compactContentActions ? 12 : 22
                anchors.topMargin: window.compactHeight ? 12 : 26
                anchors.bottomMargin: bottomConsolePanel.visible
                                      ? bottomConsolePanel.height + 18
                                      : (window.compactHeight ? 10 : 16)
                spacing: 18

                RowLayout {
                    id: topActionRow
                    

                    Layout.fillWidth: true
                    spacing: window.compactHeight ? 7 : 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: appController.selectedTool.title || "请选择工具"
                            color: Theme.textPrimary
                            font.pixelSize: window.compactContentActions ? 24 : 36
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Text {
                            text: appController.selectedTool.description || "这个人很懒，并没有写脚本介绍"
                            visible: !window.compactHeight
                            color: Theme.textSecondary
                            font.pixelSize: 15
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: !window.compactHeight && !!appController.selectedTool.executor
                            Layout.preferredWidth: runnerChipText.implicitWidth + 30
                            Layout.preferredHeight: 36
                            radius: 12
                            color: Theme.tealContainer
                            Text {
                                id: runnerChipText
                                anchors.centerIn: parent
                                text: appController.selectedTool.executor
                                      ? "›_  " + appController.selectedTool.executor.kind + " · 本地配置"
                                      : ""
                                color: Theme.teal
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    ColumnLayout {
                        id: runActionColumn
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 4

                            Rectangle {
                                visible: appController.section === "custom" && !!appController.selectedTool.id
                                         && !window.scrcpySelected
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 23
                                color: deleteMouse.containsMouse ? Theme.errorContainer : "transparent"
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: "delete"
                                    iconSize: 24
                                    color: Theme.errorColor
                                }
                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    enabled: !appController.running
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: deleteCommandDialog.open()
                                }
                            }

                            Rectangle {
                                visible: !!appController.selectedTool.editable && !window.scrcpySelected
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 23
                                color: editMouse.containsMouse ? Theme.surfaceContainer : "transparent"
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: "edit"
                                    iconSize: 24
                                    color: Theme.textSecondary
                                }
                                MouseArea {
                                    id: editMouse
                                    anchors.fill: parent
                                    enabled: !appController.running
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: commandEditorDialog.openForEdit()
                                }
                            }
                        }

                        PrimaryButton {
                            id: runCommandButton
                            visible: (!window.internalPresetSelected || window.scrcpySelected)
                                     && !!appController.selectedTool.id
                            Layout.preferredWidth: window.compactContentActions ? 58 : 176
                            Layout.preferredHeight: 48
                            compact: window.compactContentActions
                            successStyle: appController.running
                            text: appController.running
                                  ? (window.scrcpySelected ? "停止投屏" : "停止运行")
                                  : (window.scrcpySelected ? "开始投屏" : "运行命令")
                            iconName: appController.running ? "stop" : "play_arrow"
                            onClicked: {
                                if (appController.running) {
                                    appController.stopExecution()
                                } else {
                                    if (appController.selectedTool.presentation
                                            && appController.selectedTool.presentation.confirm_before_run)
                                        confirmRunDialog.openForRun(window.parameterValues)
                                    else
                                        appController.runSelected(window.parameterValues)
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: workspaceLoader
                    
                    readonly property real parameterContentHeight:
                        item && item.parameterContentHeight !== undefined
                        ? item.parameterContentHeight : 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: window.internalPresetSelected && !window.scrcpySelected
                                     ? presetWorkspace : commandWorkspace
                    onSourceComponentChanged: {
                        if (!window.scrcpySelected)
                            window.hideScrcpyWindow()
                    }
                }
            }

            ConsolePanel {
                id: bottomConsolePanel
                visible: !window.standbySelected
                         && !window.internalPresetSelected && !window.scrcpySelected
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
                minimumExpandedHeight: 160
                defaultExpandedHeight: contentPanel.height - contentLayout.y
                                       - workspaceLoader.y
                                       - workspaceLoader.parameterContentHeight - 20
                maximumExpandedHeight: Math.max(
                    minimumExpandedHeight,
                    contentPanel.height - contentLayout.y - topActionRow.y - runActionColumn.y
                    - runCommandButton.y - runCommandButton.height - 20)
                controller: appController
                panelColor: middlePanelBackdrop.color
            }
        }
    }

    MouseArea {
        id: primaryPanelResizeHandle
        property real lastWindowX: 0
        x: window.primaryNavWidth - width / 2
        anchors.top: customTitleBar.bottom
        anchors.bottom: parent.bottom
        width: 10
        z: 850
        cursorShape: Qt.SizeHorCursor
        hoverEnabled: true
        onPressed: function(mouse) {
            lastWindowX = mapToItem(window.contentItem, mouse.x, mouse.y).x
        }
        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            var currentX = mapToItem(window.contentItem, mouse.x, mouse.y).x
            window.primaryNavWidth += currentX - lastWindowX
            window.clampPanelWidths()
            lastWindowX = currentX
        }
    }

    MouseArea {
        id: toolPanelResizeHandle
        visible: !window.standbySelected
        property real lastWindowX: 0
        x: window.primaryNavWidth + window.toolListWidth - width / 2
        anchors.top: customTitleBar.bottom
        anchors.bottom: parent.bottom
        width: 10
        z: 850
        cursorShape: Qt.SizeHorCursor
        hoverEnabled: true
        onPressed: function(mouse) {
            lastWindowX = mapToItem(window.contentItem, mouse.x, mouse.y).x
        }
        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            var currentX = mapToItem(window.contentItem, mouse.x, mouse.y).x
            window.toolListWidth += currentX - lastWindowX
            window.clampPanelWidths()
            lastWindowX = currentX
        }
    }
    Component {
        id: commandWorkspace
        CommandWorkspace {
            controller: appController
            parentWindow: window
            parameterValues: window.parameterValues
            scrcpySelected: window.scrcpySelected
            overlaysVisible: settingsDialog.visible
                             || commandEditorDialog.visible
                             || deleteCommandDialog.visible
                             || confirmRunDialog.visible
        }
    }

    Component {
        id: presetWorkspace

        PresetWorkspace {
            toolController: appController
            utilities: presetController
            compact: window.compactPrimaryNav
        }
    }
    DeleteToolDialog {
        id: deleteCommandDialog
        controller: appController
        parentWindow: window
    }
    ConfirmRunDialog {
        id: confirmRunDialog
        controller: appController
        parentWindow: window
    }

    ExecutionCapacityDialog {
        controller: appController
    }

    CommandEditorDialog {
        id: commandEditorDialog
        controller: appController
    }
    PythonRestartDialog {
        id: pythonRestartDialog
        controller: settingsController
        parentWindow: window
    }
    PythonDoctorDialog {
        id: pythonDoctorDialog
        parentWindow: window
    }
    SettingsDialog {
        id: settingsDialog
        controller: settingsController
        parentWindow: window
        onRestartRequested: pythonRestartDialog.open()
    }

}
