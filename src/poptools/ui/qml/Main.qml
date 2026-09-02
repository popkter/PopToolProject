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

    Connections {
        target: settingsController
        function onThemeChanged() {
            applyThemeFromConfig()
        }
    }

    function applyThemeFromConfig() {
        try {
            var style = settingsController.themeStyle
            var jsonText = settingsController.themeConfigJson(style)
            if (!jsonText)
                return false
            return ThemeConfig.applyTheme(
                style, settingsController.darkTheme, JSON.parse(jsonText))
        } catch (error) {
            console.warn("主题应用失败：" + error)
            return false
        }
    }

    property var parameterValues: ({})
    property string toolSearchQuery: ""
    property real primaryNavWidth: Theme.navigationMaximumWidth
    property real toolListWidth: Theme.navigationMaximumWidth
    property bool developerSelected: false
    property bool terminalEnablePending: false
    property bool updateDialogPending: false
    readonly property real minimumPrimaryNavWidth: 76
    readonly property real minimumToolListWidth: 120
    readonly property real maximumNavigationWidth: Theme.navigationMaximumWidth
    readonly property real minimumContentWidth: 480
    readonly property real minimumContentHeight: 480
    readonly property bool compactPrimaryNav: primaryNavWidth < 176
    readonly property bool compactToolList: toolListWidth < 190
    readonly property bool compactContentActions: width < 760
    readonly property bool compactHeight: height < 620
    readonly property bool scrcpySelected:
        appController.selectedTool.workspace === "scrcpy"
    readonly property bool applicationOverlayVisible:
        presetFunctionsPage.popupVisible
        || executionCapacityDialog.visible
        || customScriptImportDialog.visible
        || powershellPluginDialog.visible
        || (updateDialogLoader.item && updateDialogLoader.item.visible)
        || (settingsDialogLoader.item && settingsDialogLoader.item.visible)
        || (commandEditorDialogLoader.item && commandEditorDialogLoader.item.visible)
        || (deleteCommandDialogLoader.item && deleteCommandDialogLoader.item.visible)
        || (confirmRunDialogLoader.item && confirmRunDialogLoader.item.visible)
        || (pythonDoctorDialogLoader.item && pythonDoctorDialogLoader.item.visible)
        || (userGuideDialogLoader.item && userGuideDialogLoader.item.visible)

    onToolSearchQueryChanged: appController.setToolSearchQuery(toolSearchQuery)
    function clampPanelWidths() {
        primaryNavWidth = Math.max(minimumPrimaryNavWidth,
            Math.min(primaryNavWidth,
                maximumNavigationWidth,
                width - minimumToolListWidth - minimumContentWidth))
        toolListWidth = Math.max(minimumToolListWidth,
            Math.min(toolListWidth,
                maximumNavigationWidth,
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

    function importCustomScriptFromClipboard() {
        var result = appController.importScriptFromClipboard()
        if (result.status === "duplicate") {
            customScriptImportDialog.openForReplacement(result)
        } else if (result.status === "error") {
            customScriptImportDialog.openForError(
                result.message || "剪贴板内容无法导入")
        } else {
            customTransferToast.showMessage("已导入脚本“" + result.title + "”", false)
        }
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
    onDeveloperSelectedChanged: {
        if (developerSelected)
            hideScrcpyWindow()
        if (developerSelected && appController.section === "custom")
            customScriptsPage.closeDrawerImmediately()
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

    Component.onCompleted: {
        primaryNavWidth = maximumNavigationWidth
        toolListWidth = maximumNavigationWidth
        clampPanelWidths()
        resetParameters()
        applyThemeFromConfig()
        if (settingsController.terminalEnabled
                && !developerConsoleController.pluginInstalled)
            settingsController.saveTerminalEnabled(false)
        if (!settingsController.userGuideSeen)
            window.openUserGuideDialog()
        updateController.checkForUpdatesAutomatically()
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
        anchors.topMargin: Theme.space8
        anchors.bottomMargin: Theme.space8
        width: 6
        cursorShape: Qt.SizeHorCursor
    }
    ResizeHandle {
        resizeEdges: Qt.RightEdge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.space8
        anchors.bottomMargin: Theme.space8
        width: 6
        cursorShape: Qt.SizeHorCursor
    }
    ResizeHandle {
        resizeEdges: Qt.TopEdge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space8
        anchors.rightMargin: Theme.space8
        height: 6
        cursorShape: Qt.SizeVerCursor
    }
    ResizeHandle {
        resizeEdges: Qt.BottomEdge
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space8
        anchors.rightMargin: Theme.space8
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
                    font.pixelSize: Theme.fontTitleLarge
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
            Layout.maximumWidth: window.maximumNavigationWidth
            Layout.fillHeight: true
            color: Theme.surface
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pagePadding
                anchors.rightMargin: Theme.space8
                anchors.topMargin: window.compactHeight
                    ? Theme.panelPaddingCompact : Theme.panelPadding
                anchors.bottomMargin: window.compactHeight
                    ? Theme.panelPaddingCompact : Theme.panelPadding
                spacing: window.compactHeight
                    ? Theme.controlSpacing : Theme.sectionSpacing

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.compactHeight ? 74 : 112

                    RowLayout {
                        anchors.fill: parent
                        spacing: window.compactPrimaryNav ? 0 : Theme.sectionSpacing

                        Image {
                            id: appLogo
                            Layout.preferredWidth: window.compactPrimaryNav
                                ? Theme.space32 : 58
                            Layout.preferredHeight: window.compactPrimaryNav
                                ? Theme.space32 : 58
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
                            spacing: Theme.space4
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "泡泡工具箱"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontTitleLarge
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Android 开发者工具箱"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSupporting
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
                        font.pixelSize: window.compactHeight ? Theme.fontMicro : Theme.fontCaption
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
                    selected: !window.developerSelected
                        && appController.section === "custom"
                    onClicked: {
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
                    selected: !window.developerSelected
                        && appController.section === "preset"
                    onClicked: {
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
                        window.developerSelected = true
                        developerConsoleController.ensureStarted()
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
                    actionText: updateController.state === "available"
                                ? "有新版本可用" : ""
                    onActionClicked: window.queueUpdateDialog()
                    onClicked: window.openSettingsDialog()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StackLayout {
                anchors.fill: parent
                currentIndex: window.developerSelected ? 2
                    : (appController.section === "custom" ? 0 : 1)

                CustomScriptsPage {
                    id: customScriptsPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: appController
                    parentWindow: window
                    parameterValues: window.parameterValues
                    searchQuery: window.toolSearchQuery
                    compact: window.compactContentActions
                    compactHeight: window.compactHeight
                    overlaysVisible: window.applicationOverlayVisible
                    onSearchEdited: function(query) {
                        window.toolSearchQuery = query
                    }
                    onCreateRequested: window.openCommandEditorForCreate()
                    onImportRequested: window.importCustomScriptFromClipboard()
                    onEditRequested: window.openCommandEditorForEdit()
                    onDeleteRequested: window.openDeleteCommandDialog()
                    onConfirmRunRequested: function(values) {
                        window.openConfirmRunDialog(values)
                    }
                    onToastRequested: function(message, error) {
                        customTransferToast.showMessage(message, error)
                    }
                }

                PresetFunctionsPage {
                    id: presetFunctionsPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: appController
                    parentWindow: window
                    parameterValues: window.parameterValues
                    presetUtilities: presetController
                    androidBackend: androidController
                    jiraFeishuBackend: jiraFeishuController
                    toolListWidth: window.toolListWidth
                    searchQuery: window.toolSearchQuery
                    compact: window.compactContentActions
                    compactHeight: window.compactHeight
                    compactToolList: window.compactToolList
                    overlaysVisible: window.applicationOverlayVisible
                    onSearchEdited: function(query) {
                        window.toolSearchQuery = query
                    }
                    onConfirmRunRequested: function(values) {
                        window.openConfirmRunDialog(values)
                    }
                }

                TerminalPage {
                    id: terminalPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: developerConsoleController
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
        visible: !window.developerSelected
            && appController.section !== "custom"
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
    ExecutionCapacityDialog {
        id: executionCapacityDialog
        controller: appController
    }

    CustomScriptImportDialog {
        id: customScriptImportDialog
        controller: appController
        parentWindow: window
        onScriptReplaced: function(title) {
            customTransferToast.showMessage("已替换脚本“" + title + "”", false)
        }
    }

    Popup {
        id: customTransferToast
        parent: Overlay.overlay
        property string message: ""
        property bool error: false

        function showMessage(value, isError) {
            message = value
            error = isError
            open()
            closeTimer.restart()
        }

        x: Math.round((Overlay.overlay.width - width) / 2)
        y: 18
        width: Math.min(440, Overlay.overlay.width - 24)
        height: 54
        padding: Theme.space16
        modal: false
        closePolicy: Popup.NoAutoClose
        background: Rectangle {
            radius: Theme.radiusMedium
            color: customTransferToast.error
                   ? Theme.errorContainer : Theme.surfaceContainerHigh
            border.color: customTransferToast.error
                          ? Theme.errorColor : Theme.outlineVariant
            border.width: 1
        }
        contentItem: RowLayout {
            spacing: Theme.space12
            MaterialIcon {
                icon: customTransferToast.error ? "error" : "check_circle"
                iconSize: 22
                color: customTransferToast.error ? Theme.errorColor : Theme.success
            }
            Text {
                Layout.fillWidth: true
                text: customTransferToast.message
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
            }
        }
        Timer {
            id: closeTimer
            interval: 2400
            onTriggered: customTransferToast.close()
        }
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
            updateBackend: updateController
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
            jiraFeishuBackend: jiraFeishuController
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
