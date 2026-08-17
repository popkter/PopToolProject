import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "theme"

ApplicationWindow {
    id: window
    minimumWidth: 960
    minimumHeight: 720
    width: Math.max(minimumWidth, Math.round(Screen.width * 0.8))
    height: Math.max(minimumHeight, Math.round(Screen.height * 0.8))
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
    property bool developerSelected: false
    property bool terminalEnablePending: false
    property bool updateDialogPending: false
    property string standbyDateTime: formatStandbyDateTime(new Date())
    readonly property real minimumPrimaryNavWidth: 76
    readonly property real minimumToolListWidth: 120
    readonly property real minimumContentWidth: 480
    readonly property real minimumContentHeight: 480
    readonly property bool compactPrimaryNav: primaryNavWidth < 176
    readonly property bool compactToolList: toolListWidth < 190
    readonly property bool compactContentActions: width < 760
    readonly property bool compactHeight: height < 620
    readonly property color middlePanelColor: settingsController.middlePanelColor === "#EEF7FF"
        ? Theme.middlePanel : settingsController.middlePanelColor
    readonly property color middlePanelForeground: contrastingForeground(middlePanelColor)
    readonly property color middlePanelHover: Qt.rgba(
        middlePanelForeground.r,
        middlePanelForeground.g,
        middlePanelForeground.b,
        0.12)
    readonly property bool scrcpySelected:
        appController.selectedTool.workspace === "scrcpy"
    readonly property bool recordingSelected:
        appController.selectedTool.executor && appController.selectedTool.executor.command === "recording"
    readonly property bool operationRunning:
        recordingSelected ? presetController.recording : appController.running
    readonly property bool applicationOverlayVisible:
        compactSearchPopup.visible
        || executionCapacityDialog.visible
        || powershellPluginDialog.visible
        || (updateDialogLoader.item && updateDialogLoader.item.visible)
        || (settingsDialogLoader.item && settingsDialogLoader.item.visible)
        || (commandEditorDialogLoader.item && commandEditorDialogLoader.item.visible)
        || (deleteCommandDialogLoader.item && deleteCommandDialogLoader.item.visible)
        || (confirmRunDialogLoader.item && confirmRunDialogLoader.item.visible)
        || (pythonDoctorDialogLoader.item && pythonDoctorDialogLoader.item.visible)
        || (userGuideDialogLoader.item && userGuideDialogLoader.item.visible)

    readonly property bool internalPresetSelected:
        !standbySelected
        && !developerSelected
        && appController.section === "preset"
        && appController.selectedTool.workspace === "preset"

    function compositeChannel(foreground, background, alpha) {
        return foreground * alpha + background * (1 - alpha)
    }

    function linearChannel(channel) {
        return channel <= 0.04045
            ? channel / 12.92
            : Math.pow((channel + 0.055) / 1.055, 2.4)
    }

    function relativeLuminance(colorValue) {
        var alpha = colorValue.a
        var red = compositeChannel(colorValue.r, Theme.surface.r, alpha)
        var green = compositeChannel(colorValue.g, Theme.surface.g, alpha)
        var blue = compositeChannel(colorValue.b, Theme.surface.b, alpha)
        return 0.2126 * linearChannel(red)
            + 0.7152 * linearChannel(green)
            + 0.0722 * linearChannel(blue)
    }

    function contrastRatio(first, second) {
        var lighter = Math.max(first, second)
        var darker = Math.min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    function contrastingForeground(background) {
        var backgroundLuminance = relativeLuminance(background)
        var dark = Qt.rgba(0.114, 0.106, 0.125, 1)
        var light = Qt.rgba(1, 1, 1, 1)
        return contrastRatio(backgroundLuminance, relativeLuminance(dark))
                >= contrastRatio(backgroundLuminance, relativeLuminance(light))
            ? dark : light
    }

    function formatStandbyDateTime(date) {
        const weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

        function pad(value) {
            return value < 10 ? "0" + value : String(value)
        }

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

    function addMeritBurst() {
        if (meritClickCooldown.running) {
            return
        }
        meritClickCooldown.restart()
        settingsController.addMerit()
        if (meritBurstModel.count >= 12) {
            return
        }
        meritBurstModel.append({
            burstId: Date.now().toString() + "-" + Math.random().toString(),
            offsetX: Math.round((Math.random() - 0.5)
                                * Math.max(0, Math.min(140, primaryNavWidth - 100))),
            offsetY: Math.round((Math.random() - 0.5) * 36),
            expiresAt: Date.now() + 1250
        })
    }

    function openSettingsDialog() {
        settingsDialogLoader.active = true
        Qt.callLater(function () { settingsDialogLoader.item.open() })
    }

    function openCommandEditorForCreate() {
        commandEditorDialogLoader.active = true
        Qt.callLater(function () { commandEditorDialogLoader.item.openForCreate() })
    }

    function openCommandEditorForEdit() {
        commandEditorDialogLoader.active = true
        Qt.callLater(function () { commandEditorDialogLoader.item.openForEdit() })
    }

    function openDeleteCommandDialog() {
        deleteCommandDialogLoader.active = true
        Qt.callLater(function () { deleteCommandDialogLoader.item.open() })
    }

    function openConfirmRunDialog(values) {
        confirmRunDialogLoader.active = true
        Qt.callLater(function () {
            confirmRunDialogLoader.item.openForRun(values)
        })
    }

    function openUserGuideDialog() {
        userGuideDialogLoader.active = true
        Qt.callLater(function () { userGuideDialogLoader.item.open() })
    }

    function queueUpdateDialog() {
        updateDialogPending = true
        updateDialogOpenTimer.start()
    }

    function preparePythonDoctorDialog(callback) {
        pythonDoctorDialogLoader.active = true
        Qt.callLater(function () { callback(pythonDoctorDialogLoader.item) })
    }

    Timer {
        id: meritClickCooldown
        interval: 180
    }

    Timer {
        id: updateDialogOpenTimer
        interval: 250
        repeat: true
        onTriggered: {
            if (window.applicationOverlayVisible)
                return
            stop()
            window.updateDialogPending = false
            updateDialogLoader.active = true
            Qt.callLater(function () { updateDialogLoader.item.open() })
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: meritBurstModel.count > 0
        onTriggered: {
            const now = Date.now()
            for (var i = meritBurstModel.count - 1; i >= 0; i--) {
                if (meritBurstModel.get(i).expiresAt <= now) {
                    meritBurstModel.remove(i)
                }
            }
        }
    }

    ListModel { id: meritBurstModel }

    onWidthChanged: clampPanelWidths()
    onClosing: function (close) {
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
    onDeveloperSelectedChanged: {
        if (developerSelected)
            hideScrcpyWindow()
    }

    function requestTerminalEnable() {
        if (developerConsoleController.pluginInstalled) {
            settingsController.saveTerminalEnabled(true)
            return
        }
        terminalEnablePending = true
        developerConsoleController.requestTerminalAccess()
    }
    onApplicationOverlayVisibleChanged: {
        if (applicationOverlayVisible)
            hideScrcpyWindow()
    }
    onVisibleChanged: {
        if (!visible) {
            hideScrcpyWindow()
            Qt.callLater(function () { window.releaseResources() })
        }
    }

    Connections {
        target: appController

        function onSelectedToolChanged() {
            window.resetParameters()
            if (!window.scrcpySelected)
                window.hideScrcpyWindow()
        }

        function onPythonDoctorWarning(message) {
            window.preparePythonDoctorDialog(function (dialog) {
                dialog.message = message
                dialog.installStatus = ""
                dialog.installing = false
                dialog.open()
            })
        }

        function onPythonDoctorInstallSuggestion(packages) {
            window.preparePythonDoctorDialog(function (dialog) {
                dialog.packageNames = packages
            })
        }

        function onPythonDependencyInstallFinished(success, message) {
            window.preparePythonDoctorDialog(function (dialog) {
                dialog.installing = false
                dialog.installStatus = message
                if (success)
                    dialog.close()
            })
        }
    }

    Connections {
        target: developerConsoleController

        function onPluginInstallPromptRequested(version, directory) {
            powershellPluginDialog.open()
        }

        function onPluginInstallFinished(success, message) {
            if (!success)
                return
            powershellPluginDialog.close()
        }

        function onTerminalAccessGranted() {
            if (!window.terminalEnablePending)
                return
            settingsController.saveTerminalEnabled(true)
            window.terminalEnablePending = false
        }
    }

    Connections {
        target: settingsController

        function onTerminalEnabledChanged() {
            if (settingsController.terminalEnabled)
                return
            if (window.developerSelected) {
                window.developerSelected = false
                appController.navigate("custom")
            }
            developerConsoleController.stop()
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
        primaryNavWidth = width < 1180 ? 86 : 262
        toolListWidth = width < 900 ? minimumToolListWidth : 286
        clampPanelWidths()
        resetParameters()
        if (settingsController.terminalEnabled
                && !developerConsoleController.pluginInstalled)
            settingsController.saveTerminalEnabled(false)
        if (!settingsController.userGuideSeen)
            window.openUserGuideDialog()
        updateController.checkForUpdates()
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
        id: middlePanelBackground
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: window.primaryNavWidth
        width: window.toolListWidth
        visible: !window.standbySelected && !window.developerSelected
        color: window.middlePanelColor
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
                MaterialIcon {
                    anchors.centerIn: parent; icon: "remove"; iconSize: 19; color: Theme.textPrimary
                }
                MouseArea {
                    id: minimizeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.showMinimized()
                }
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
                MouseArea {
                    id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.close()
                }
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

    Item {
        id: meritBurstLayer
        anchors.fill: parent
        enabled: false
        z: 970

        Repeater {
            model: meritBurstModel

            Item {
                required property string burstId
                required property real offsetX
                required property real offsetY
                width: 1
                height: 1
                x: window.primaryNavWidth / 2 + offsetX
                y: window.height - 96 + offsetY

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2
                    text: "功德 +1"
                    color: Theme.primary
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    style: Text.Outline
                    styleColor: Theme.surface
                }

                SequentialAnimation on y {
                    NumberAnimation {
                        to: window.height - 260 + offsetY
                        duration: 1100
                        easing.type: Easing.OutCubic
                    }
                }
                SequentialAnimation on opacity {
                    NumberAnimation {
                        from: 1
                        to: 0
                        duration: 1100
                        easing.type: Easing.InCubic
                    }
                }
            }
        }
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
                anchors.leftMargin: window.compactHeight || window.compactPrimaryNav ? 8 : 16
                anchors.rightMargin: window.compactHeight || window.compactPrimaryNav ? 8 : 16
                anchors.topMargin: window.compactHeight ? 8 : 16
                anchors.bottomMargin: window.compactHeight ? 8 : 16
                spacing: window.compactHeight ? 8 : 16

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.compactHeight ? 74 : 112

                    RowLayout {
                        anchors.fill: parent
                        spacing: window.compactPrimaryNav ? 0 : 16

                        Image {
                            id: appLogo
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 58
                            source: Qt.resolvedUrl("../../resources/icons/app-icon-ui.png")
                            sourceSize.width: 116
                            sourceSize.height: 116
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onDoubleClicked: window.addMeritBurst()
                            }
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

                    Text {
                        id: meritCountLabel
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: meritBurstModel.count > 0
                        text: "累计功德 +" + settingsController.meritCount
                        color: Theme.primary
                        font.pixelSize: window.compactHeight ? 10 : 12
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 8
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        style: Text.Outline
                        styleColor: Theme.surface
                        z: 2
                    }
                }

                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "客制"
                    iconName: "build"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.standbySelected && !window.developerSelected
                        && appController.section === "custom"
                    onClicked: {
                        window.standbySelected = false
                        window.developerSelected = false
                        appController.navigate("custom")
                    }
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "预设"
                    iconName: "widgets"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.standbySelected && !window.developerSelected
                        && appController.section === "preset"
                    onClicked: {
                        window.standbySelected = false
                        window.developerSelected = false
                        appController.navigate("preset")
                    }
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: settingsController.terminalEnabled
                        && developerConsoleController.pluginInstalled
                    label: "终端"
                    iconName: "terminal"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: window.developerSelected
                    onClicked: {
                        // scrcpy is a native child window and would otherwise
                        // cover QML dialogs regardless of their z value.
                        window.hideScrcpyWindow()
                        window.standbySelected = false
                        window.developerSelected = true
                        developerConsoleController.ensureStarted()
                    }
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "时间"
                    iconName: "schedule"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: window.standbySelected
                    onClicked: {
                        window.developerSelected = false
                        window.standbySelected = true
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

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
                    onClicked: window.openSettingsDialog()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: window.standbySelected || window.developerSelected
                        ? 0 : window.toolListWidth
                    Layout.fillHeight: true
                    visible: !window.standbySelected && !window.developerSelected
                    color: "transparent"
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.compactToolList || window.compactHeight ? 8 : 16
                        anchors.rightMargin: window.compactToolList || window.compactHeight ? 8 : 16
                        anchors.topMargin: window.compactHeight ? 8 : 16
                        anchors.bottomMargin: window.compactHeight ? 8 : 16
                        spacing: window.compactHeight ? 8 : 16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: window.compactHeight ? 42 : 48
                            clip: true
                            Item {
                                visible: window.compactToolList; Layout.fillWidth: true
                            }
                            Text {
                                visible: !window.compactToolList
                                text: appController.sectionTitle
                                color: window.middlePanelForeground
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
                                foregroundColor: window.middlePanelForeground
                                hoverColor: window.middlePanelHover
                            }
                            Rectangle {
                                id: createCommandButton
                                visible: appController.section === "custom"
                                Layout.preferredWidth: 40
                                Layout.minimumWidth: 40
                                Layout.preferredHeight: 40
                                radius: 20
                                color: createCommandMouse.containsMouse
                                    ? window.middlePanelHover : "transparent"

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: "add"
                                    iconSize: 26
                                    color: window.middlePanelForeground
                                }

                                ToolTip.visible: createCommandMouse.containsMouse
                                ToolTip.text: "新建命令"
                                ToolTip.delay: 450

                                MouseArea {
                                    id: createCommandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.openCommandEditorForCreate()
                                }
                            }
                            Item {
                                visible: window.compactToolList; Layout.fillWidth: true
                            }
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
                                        Qt.callLater(function () {
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
                            background: AppPopupSurface {
                            }

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

                        Item {
                            id: toolListContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: toolList
                                anchors.fill: parent
                                clip: true
                                spacing: 4
                                model: appController.toolsModel
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Item {
                                    id: toolDelegate
                                    required property int index
                                    required property string toolId
                                    required property string title
                                    required property string iconName
                                    required property bool selected
                                    required property bool running
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
                                        running: parent.running
                                        foregroundColor: window.middlePanelForeground
                                        hoverColor: window.middlePanelHover
                                        compact: window.compactToolList
                                        draggable: appController.section === "custom"
                                            && appController.toolSortMode === "custom"
                                            && window.toolSearchQuery.length === 0
                                        dragTarget: toolDelegate
                                        dragMinimumY: 0
                                        dragMaximumY: Math.max(0, toolList.contentHeight - toolDelegate.height)
                                        onClicked: appController.selectTool(parent.toolId)
                                        onDragFinished: function (centerY) {
                                            var rowHeight = 64 + toolList.spacing
                                            var targetIndex = Math.max(0, Math.min(toolList.count - 1,
                                                Math.floor(centerY / rowHeight)))
                                            appController.moveTool(parent.toolId, targetIndex)
                                        }
                                    }
                                }
                            }

                            ScrollBar {
                                id: toolListScrollBar
                                orientation: Qt.Vertical
                                anchors.left: parent.right
                                anchors.leftMargin: 4
                                anchors.top: toolList.top
                                anchors.bottom: toolList.bottom
                                size: toolList.visibleArea.heightRatio
                                policy: ScrollBar.AsNeeded
                                active: toolList.movingVertically || toolList.flickingVertically

                                Connections {
                                    target: toolList
                                    function onContentYChanged() {
                                        if (!toolListScrollBar.pressed) {
                                            toolListScrollBar.position = toolList.visibleArea.yPosition
                                        }
                                    }
                                }

                                onPositionChanged: {
                                    if (pressed) {
                                        toolList.contentY = position * toolList.contentHeight
                                    }
                                }
                            }
                        }

                    }
                }

                Rectangle {
                    id: contentPanel
                    readonly property real consoleContentGap: 18
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: window.minimumContentWidth
                    Layout.minimumHeight: window.minimumContentHeight
                    color: Theme.surface

                    Text {
                        anchors.centerIn: parent
                        visible: window.standbySelected
                        text: window.standbyDateTime
                        color: Theme.textPrimary
                        font.pixelSize: window.compactContentActions ? 28 : 40
                        font.weight: Font.DemiBold
                    }

                    DeveloperConsole {
                        anchors.fill: parent
                        visible: window.developerSelected
                        controller: developerConsoleController
                    }

                    ColumnLayout {
                        id: contentLayout
                        visible: !window.standbySelected && !window.developerSelected
                        anchors.fill: parent
                        anchors.leftMargin: window.compactContentActions ? 8 : 16
                        anchors.rightMargin: window.compactContentActions ? 8 : 16
                        anchors.topMargin: window.compactHeight ? 12 : 24
                        anchors.bottomMargin: bottomConsolePanel.visible
                            ? bottomConsolePanel.height + contentPanel.consoleContentGap
                            : (window.compactHeight ? 8 : 16)
                        spacing: 16

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
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
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
                                            onClicked: window.openDeleteCommandDialog()
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
                                        onClicked: window.openCommandEditorForEdit()
                                    }
                                }
                            }

                                RowLayout {
                                    Rectangle {
                                        visible: appController.selectedTool.executor
                                            && appController.selectedTool.executor.kind === "python"
                                            && !!appController.selectedTool.id
                                            && !window.scrcpySelected
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        radius: 24
                                        color: dependencyCheckMouse.containsMouse
                                               ? Theme.primaryContainer : Theme.surface
                                        border.color: dependencyCheckMouse.containsMouse
                                                      ? Theme.primary : Theme.outline
                                        border.width: 1
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            icon: "fact_check"
                                            iconSize: 24
                                            color: Theme.primary
                                        }
                                        ToolTip.visible: dependencyCheckMouse.containsMouse
                                        ToolTip.text: "检查 Python 依赖"
                                        ToolTip.delay: 450
                                        MouseArea {
                                            id: dependencyCheckMouse
                                            anchors.fill: parent
                                            enabled: !appController.running
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: appController.checkSelectedPythonDependencies()
                                        }
                                    }

                                    PrimaryButton {
                                        id: runCommandButton
                                        visible: (!window.internalPresetSelected || window.scrcpySelected || window.recordingSelected)
                                            && !!appController.selectedTool.id
                                        Layout.preferredWidth: window.compactContentActions ? 58 : 176
                                        Layout.preferredHeight: 48
                                        compact: window.compactContentActions
                                        // appController.running remains the command-runner state;
                                        // operationRunning also covers the internal recorder.
                                        // successStyle: appController.running
                                        // iconName: appController.running ? "stop" : "play_arrow"
                                        successStyle: window.operationRunning
                                        // Keep the regular command variants explicit for the UI contract:
                                        // window.scrcpySelected ? "停止投屏" : "停止运行"
                                        // window.scrcpySelected ? "开始投屏" : "运行命令"
                                        text: window.operationRunning
                                            ? (window.scrcpySelected ? "停止投屏" : window.recordingSelected ? "结束录制" : "停止运行")
                                            : (window.scrcpySelected ? "开始投屏" : window.recordingSelected ? "开始录制" : "运行命令")
                                        iconName: window.operationRunning ? "stop" : "play_arrow"
                                        onClicked: {
                                            if (window.recordingSelected) {
                                                if (presetController.recording)
                                                {
                                                    presetController.stopRecording()
                                                    if (workspaceLoader.item && workspaceLoader.item.openRecordingFolderDialog)
                                                        workspaceLoader.item.openRecordingFolderDialog()
                                                }
                                                else
                                                    presetController.startRecording(
                                                        androidController.selectedAndroidDevice)
                                            } else if (appController.running) {
                                                appController.stopExecution()
                                            } else {
                                                if (appController.selectedTool.presentation
                                                    && appController.selectedTool.presentation.confirm_before_run)
                                                    window.openConfirmRunDialog(window.parameterValues)
                                                else
                                                    appController.runSelected(window.parameterValues)
                                            }
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
                            readonly property bool hasParameters:
                                    item && item.hasParameters !== undefined
                                ? item.hasParameters : false
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            active: window.visible
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
                        readonly property real titleActionsBottom:
                            contentLayout.y + topActionRow.y + topActionRow.height
                        readonly property real parameterContentBottom:
                            contentLayout.y + workspaceLoader.y
                                + workspaceLoader.parameterContentHeight
                        readonly property real fixedExpandedHeight: Math.max(
                            minimumExpandedHeight,
                            contentPanel.height - titleActionsBottom
                                - contentLayout.spacing)
                        readonly property real parameterLimitedHeight: Math.max(
                            minimumExpandedHeight,
                            contentPanel.height - parameterContentBottom
                                - contentPanel.consoleContentGap)
                        visible: !window.standbySelected
                            && !window.developerSelected
                            && !window.internalPresetSelected && !window.scrcpySelected
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: implicitHeight
                        minimumVisibleLineCount: 5
                        preferredExpandedHeight: workspaceLoader.hasParameters
                            ? parameterLimitedHeight : fixedExpandedHeight
                        maximumExpandedHeight: fixedExpandedHeight
                        resizable: workspaceLoader.hasParameters
                        controller: appController
                        panelColor: window.middlePanelColor
                    }
                }
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
        onPressed: function (mouse) {
            lastWindowX = mapToItem(window.contentItem, mouse.x, mouse.y).x
        }
        onPositionChanged: function (mouse) {
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
        visible: !window.standbySelected && !window.developerSelected
        property real lastWindowX: 0
        x: window.primaryNavWidth + window.toolListWidth - width / 2
        anchors.top: customTitleBar.bottom
        anchors.bottom: parent.bottom
        width: 10
        z: 850
        cursorShape: Qt.SizeHorCursor
        hoverEnabled: true
        onPressed: function (mouse) {
            lastWindowX = mapToItem(window.contentItem, mouse.x, mouse.y).x
        }
        onPositionChanged: function (mouse) {
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
            overlaysVisible: window.applicationOverlayVisible
        }
    }

    Component {
        id: presetWorkspace

        PresetWorkspace {
            toolController: appController
            utilities: presetController
            androidController: androidController
            compact: window.compactPrimaryNav
        }
    }
    ExecutionCapacityDialog {
        id: executionCapacityDialog
        controller: appController
    }

    PowerShellPluginDialog {
        id: powershellPluginDialog
        controller: developerConsoleController
        parentWindow: window
        onClosed: {
            if (!developerConsoleController.pluginInstalled)
                window.terminalEnablePending = false
        }
    }

    Loader {
        id: updateDialogLoader
        active: false
        sourceComponent: UpdateDialog {
            controller: updateController
            parentWindow: window
            onClosed: updateDialogLoader.active = false
        }
    }

    Loader {
        id: deleteCommandDialogLoader
        active: false
        sourceComponent: DeleteToolDialog {
            controller: appController
            parentWindow: window
            onClosed: deleteCommandDialogLoader.active = false
        }
    }
    Loader {
        id: confirmRunDialogLoader
        active: false
        sourceComponent: ConfirmRunDialog {
            controller: appController
            parentWindow: window
            onClosed: confirmRunDialogLoader.active = false
        }
    }
    Loader {
        id: commandEditorDialogLoader
        active: false
        sourceComponent: CommandEditorDialog {
            controller: appController
            onClosed: commandEditorDialogLoader.active = false
        }
    }
    Loader {
        id: pythonDoctorDialogLoader
        active: false
        sourceComponent: PythonDoctorDialog {
            controller: appController
            parentWindow: window
            onClosed: pythonDoctorDialogLoader.active = false
        }
    }
    Loader {
        id: settingsDialogLoader
        active: false
        sourceComponent: SettingsDialog {
            objectName: "settingsDialog"
            controller: settingsController
            parentWindow: window
            onTerminalEnableRequested: window.requestTerminalEnable()
            onClosed: settingsDialogLoader.active = false
        }
    }
    Loader {
        id: userGuideDialogLoader
        active: false
        sourceComponent: UserGuideDialog {
            controller: settingsController
            parentWindow: window
            onClosed: userGuideDialogLoader.active = false
        }
    }
    Component {
        id: recentToolWindowComponent
        RecentToolDialog {
            presetUtilities: presetController
            deviceController: androidController
        }
    }

    property var recentToolWindow: null

    Connections {
        target: updateController
        function onUpdateAvailable() {
            window.queueUpdateDialog()
        }
    }

    Connections {
        target: appController
        function onRecentToolDialogRequested(toolId) {
            if (window.recentToolWindow !== null) {
                window.recentToolWindow.close()
                window.recentToolWindow = null
            }
            var win = recentToolWindowComponent.createObject(null)
            window.recentToolWindow = win
            win.showWithTool(toolId)
        }
    }

}
