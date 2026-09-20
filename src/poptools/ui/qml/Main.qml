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
    readonly property real primaryNavWidth: 64
    readonly property real toolListWidth: Math.max(
        minimumToolListWidth,
        Math.min(maximumNavigationWidth,
                 width - primaryNavWidth - minimumContentWidth))
    property bool developerSelected: false
    property bool settingsSelected: false
    property bool terminalEnablePending: false
    property bool updateDialogPending: false
    readonly property real minimumToolListWidth: 120
    readonly property real maximumNavigationWidth: Theme.navigationMaximumWidth
    readonly property real minimumContentWidth: 480
    readonly property real minimumContentHeight: 480
    property bool compactPrimaryNav: true
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
        || (commandEditorDialogLoader.item && commandEditorDialogLoader.item.visible)
        || (deleteCommandDialogLoader.item && deleteCommandDialogLoader.item.visible)
        || (confirmRunDialogLoader.item && confirmRunDialogLoader.item.visible)
        || (pythonDoctorDialogLoader.item && pythonDoctorDialogLoader.item.visible)
        || (userGuideDialogLoader.item && userGuideDialogLoader.item.visible)

    onToolSearchQueryChanged: appController.setToolSearchQuery(toolSearchQuery)
    function openTerminalPage() {
        if (!developerConsoleController.pluginInstalled) {
            window.requestTerminalEnable()
            return
        }
        window.hideScrcpyWindow()
        window.developerSelected = true
        window.settingsSelected = false
        developerConsoleController.ensureStarted()
    }

    function openCustomScriptsPage() {
        window.hideScrcpyWindow()
        window.developerSelected = false
        window.settingsSelected = false
        appController.navigate("custom")
    }

    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: !window.applicationOverlayVisible
        onActivated: {
            if (window.developerSelected && !window.settingsSelected) {
                if (developerConsoleController.canCreateTerminalTab)
                    developerConsoleController.createTerminalTab()
            } else {
                window.openTerminalPage()
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Q"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: !window.applicationOverlayVisible
        onActivated: window.openCustomScriptsPage()
    }

    function openSettingsDialog() {
        developerSelected = false
        settingsSelected = true
        hideScrcpyWindow()
    }

    function openCommandEditorForCreate(command, kind) {
        commandEditorDialogLoader.active = true
        Qt.callLater(function () { commandEditorDialogLoader.item.openForCreate(command, kind) })
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
        // Break the initial Screen-based bindings so interactive resizing owns
        // the window geometry after startup.
        window.width = Math.max(window.minimumWidth,
                                Math.round(Screen.width * 0.8))
        window.height = Math.max(window.minimumHeight,
                                 Math.round(Screen.height * 0.8))
        resetParameters()
        if (settingsController.terminalEnabled
                && !developerConsoleController.pluginInstalled)
            settingsController.saveTerminalEnabled(false)
        if (!settingsController.userGuideSeen)
            window.openUserGuideDialog()
        if (updateController.state === "downloaded")
            window.queueUpdateDialog()
        else
            updateController.checkForUpdatesAutomatically()
    }

    component ResizeHandle: MouseArea {
        required property int resizeEdges
        property bool systemResizeActive: false
        property real resizeStartGlobalX: 0
        property real resizeStartGlobalY: 0
        property real resizeStartX: 0
        property real resizeStartY: 0
        property real resizeStartWidth: 0
        property real resizeStartHeight: 0

        visible: window.visibility !== Window.Maximized
        z: 1000
        hoverEnabled: true
        preventStealing: true

        onPressed: function(mouse) {
            // Let the window manager synchronize both axes and the window position.
            // Separate geometry writes expose intermediate sizes during corner drags.
            systemResizeActive = window.startSystemResize(resizeEdges)
            mouse.accepted = true
            if (systemResizeActive)
                return

            const globalPoint = mapToGlobal(mouse.x, mouse.y)
            resizeStartGlobalX = globalPoint.x
            resizeStartGlobalY = globalPoint.y
            resizeStartX = window.x
            resizeStartY = window.y
            resizeStartWidth = window.width
            resizeStartHeight = window.height
        }

        onPositionChanged: function(mouse) {
            if (!pressed || systemResizeActive)
                return

            const globalPoint = mapToGlobal(mouse.x, mouse.y)
            const deltaX = globalPoint.x - resizeStartGlobalX
            const deltaY = globalPoint.y - resizeStartGlobalY
            const resizeLeft = (resizeEdges & Qt.LeftEdge) !== 0
            const resizeRight = (resizeEdges & Qt.RightEdge) !== 0
            const resizeTop = (resizeEdges & Qt.TopEdge) !== 0
            const resizeBottom = (resizeEdges & Qt.BottomEdge) !== 0
            let newX = resizeStartX
            let newY = resizeStartY
            let newWidth = resizeStartWidth
            let newHeight = resizeStartHeight

            if (resizeLeft || resizeRight) {
                const requestedWidth = resizeLeft
                    ? resizeStartWidth - deltaX
                    : resizeStartWidth + deltaX
                newWidth = Math.round(Math.max(
                    window.minimumWidth,
                    Math.min(window.maximumWidth, requestedWidth)))
                if (resizeLeft)
                    newX = resizeStartX + resizeStartWidth - newWidth
            }

            if (resizeTop || resizeBottom) {
                const requestedHeight = resizeTop
                    ? resizeStartHeight - deltaY
                    : resizeStartHeight + deltaY
                newHeight = Math.round(Math.max(
                    window.minimumHeight,
                    Math.min(window.maximumHeight, requestedHeight)))
                if (resizeTop)
                    newY = resizeStartY + resizeStartHeight - newHeight
            }

            // Platforms without native resizing still receive one geometry update.
            if (window.x !== newX || window.y !== newY
                    || window.width !== newWidth || window.height !== newHeight)
                window.setGeometry(newX, newY, newWidth, newHeight)
        }
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
        height: 40
        color: window.developerSelected
            ? (Theme.darkMode ? Theme.sidebar : "#F7F8FA") : Theme.surface
        z: 900

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: window.primaryNavWidth
            color: Theme.darkMode ? Theme.sidebar : "#F7F8FA"
            z: -1
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
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
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 6
            z: 2

            Rectangle {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                radius: 6
                color: "#FF5F57"
                MaterialIcon {
                    anchors.centerIn: parent; icon: "close"; iconSize: 9
                    color: closeArea.containsMouse ? "#6B1512" : "transparent"
                }
                MouseArea {
                    id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.close()
                }
            }
            Rectangle {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                radius: 6
                color: "#FFBD2E"
                MaterialIcon {
                    anchors.centerIn: parent; icon: "remove"; iconSize: 9
                    color: minimizeArea.containsMouse ? "#765300" : "transparent"
                }
                MouseArea {
                    id: minimizeArea; anchors.fill: parent; hoverEnabled: true; onClicked: window.showMinimized()
                }
            }
            Rectangle {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                radius: 6
                color: "#28C840"
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: window.visibility === Window.Maximized ? "filter_none" : "crop_square"
                    iconSize: 8
                    color: maximizeArea.containsMouse ? "#0A5B16" : "transparent"
                }
                MouseArea {
                    id: maximizeArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: window.visibility === Window.Maximized
                        ? window.showNormal() : window.showMaximized()
                }
            }
        }

        Text {
            visible: window.developerSelected
            anchors.left: parent.left
            anchors.leftMargin: window.primaryNavWidth + 12
            anchors.verticalCenter: parent.verticalCenter
            text: "UTerminal"
            color: Theme.darkMode ? Theme.textPrimary : "#252A31"
            font.pixelSize: 14
            font.weight: Font.DemiBold
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
            Layout.minimumWidth: window.primaryNavWidth
            Layout.maximumWidth: window.primaryNavWidth
            Layout.fillHeight: true
            color: Theme.darkMode ? Theme.sidebar : "#F7F8FA"
            clip: false
            z: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space12
                anchors.rightMargin: Theme.space12
                anchors.topMargin: Theme.space8
                anchors.bottomMargin: Theme.space12
                spacing: Theme.space8

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 40
                        spacing: 0

                        Image {
                            id: appLogo
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            source: Qt.resolvedUrl("../../resources/icons/app-icon-ui.png")
                            sourceSize.width: 116
                            sourceSize.height: 116
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
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
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "Android 开发者工具"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSupporting
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: true
                    label: "终端"
                    shortcutText: "Ctrl+T"
                    iconName: "terminal"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: window.developerSelected && !window.settingsSelected
                    onClicked: window.openTerminalPage()
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "自定义"
                    shortcutText: "Ctrl+Q"
                    iconName: "build"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.developerSelected && !window.settingsSelected
                        && appController.section === "custom"
                    onClicked: window.openCustomScriptsPage()
                }
                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "预设"
                    iconName: "widgets"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: !window.developerSelected && !window.settingsSelected
                        && appController.section === "preset"
                    onClicked: {
                        window.developerSelected = false
                        window.settingsSelected = false
                        appController.navigate("preset")
                    }
                }

                NavItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    label: "设置"
                    iconName: "settings"
                    compact: window.compactPrimaryNav
                    dense: window.compactHeight
                    selected: window.settingsSelected
                    actionText: updateController.state === "available"
                                ? "有新版本可用"
                                : updateController.state === "downloaded"
                                  ? "更新已准备好" : ""
                    onActionClicked: window.queueUpdateDialog()
                    onClicked: window.openSettingsDialog()
                }

                Item {
                    Layout.fillHeight: true
                }

            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StackLayout {
                anchors.fill: parent
                currentIndex: window.settingsSelected ? 3
                    : window.developerSelected ? 2
                    : (appController.section === "custom" ? 0 : 1)

                CustomScriptsPage {
                    id: customScriptsPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: appController
                    androidBackend: androidController
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
                    parentWindow: window
                    onCreateScriptRequested: function(command, kind) {
                        window.openCommandEditorForCreate(command, kind)
                    }
                }

                SettingsPage {
                    id: settingsPage
                    objectName: "settingsDialog"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: settingsController
                    updateBackend: updateController
                    onTerminalEnableRequested: window.requestTerminalEnable()
                }
            }
        }

    }

    ExecutionCapacityDialog {
        id: executionCapacityDialog
        controller: appController
    }

    CustomScriptImportDialog {
        id: customScriptImportDialog
        objectName: "customScriptImportDialog"
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
        background: AppPopupSurface {
            fillColor: customTransferToast.error
                       ? Theme.errorContainer : Theme.popupSurface
            outlineColor: customTransferToast.error
                          ? Theme.errorColor : Theme.outlineVariant
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
