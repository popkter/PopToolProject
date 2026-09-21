import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import "../theme"

AppDialog {
    id: root
    objectName: "userGuideDialog"
    required property var controller
    required property var parentWindow
    property bool loadFailed: false
    property bool pageLoaded: false
    readonly property string guideTheme: JSON.stringify({
        "dark": Theme.darkMode,
        "colors": {
            "ink": String(Theme.textPrimary), "muted": String(Theme.textSecondary),
            "green": String(Theme.primaryText), "line": String(Theme.outlineVariant),
            "paper": String(Theme.surface), "lime": String(Theme.primaryForeground),
            "canvas": String(Theme.surfaceContainer), "card": String(Theme.surfaceContainerLow),
            "accent": String(Theme.primary), "soft": String(Theme.primaryContainer),
            "border": String(Theme.outline), "code-bg": String(Theme.consoleBackground),
            "code-text": String(Theme.consoleText), "code-muted": String(Theme.consoleMuted),
            "error": String(Theme.errorColor)
        }
    })
    onGuideThemeChanged: applyGuideTheme()

    function applyGuideTheme() {
        if (pageLoaded && webViewLoader.item)
            webViewLoader.item.runJavaScript("window.applyAppTheme && window.applyAppTheme(" + guideTheme + ");")
    }

    function runGuideJavaScript(script, callback) {
        if (webViewLoader.item)
            webViewLoader.item.runJavaScript(script, callback)
    }

    width: Math.min(900, parentWindow.width - 24)
    height: Math.min(840, parentWindow.height - 24)
    anchors.centerIn: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape
    padding: 0
    // The help page is opaque and rectangular. Avoid an offscreen shadow
    // texture around WebEngine, which can leave a black rectangle outside it.
    background: Rectangle {
        color: Theme.surface
        radius: 0
    }

    onAboutToHide: {
        if (pageLoaded)
            controller.markUserGuideSeen()
    }
    onAboutToShow: {
        pageLoaded = false
        loadFailed = false
    }

    function finishGuide() { close() }

    contentItem: Item {
        clip: true
        Loader {
            id: webViewLoader
            anchors.fill: parent
            active: root.opened
            asynchronous: false

            sourceComponent: Component {
                WebEngineView {
                    id: guideView
                    objectName: "userGuideWebView"
                    url: root.controller.userGuideUrl
                    // Keep the backing surface opaque. Together with delayed
                    // creation this prevents exposed black Chromium tiles.
                    backgroundColor: Theme.surface
                    settings.javascriptCanAccessClipboard: true
                    settings.localContentCanAccessRemoteUrls: false
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_F12)
                            event.accepted = true
                    }
                    onContextMenuRequested: function(request) {
                        request.accepted = true
                    }
                    onNavigationRequested: function(request) {
                        if (request.url.toString() === root.controller.userGuideUrl.toString() + "?guide-action=close") {
                            request.reject()
                            root.finishGuide()
                            return
                        }
                        // Keep the guide and its section links inside this local document.
                        if (request.url.toString().split("#")[0] !== root.controller.userGuideUrl.toString())
                            request.reject()
                    }
                    onLoadingChanged: function(request) {
                        if (request.status === WebEngineView.LoadSucceededStatus) {
                            root.pageLoaded = true
                            root.loadFailed = false
                            root.applyGuideTheme()
                        } else if (request.status === WebEngineView.LoadFailedStatus) {
                            root.loadFailed = true
                        }
                    }
                }
            }
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: webViewLoader.item && webViewLoader.item.loading
            visible: running
        }
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.loadFailed
            Text {
                text: "手册加载失败，请重试。"
                color: Theme.textPrimary
            }
            PrimaryButton {
                text: "关闭"
                onClicked: root.finishGuide()
            }
            PrimaryButton {
                text: "重新加载"
                onClicked: {
                    root.loadFailed = false
                    if (webViewLoader.item)
                        webViewLoader.item.reload()
                }
            }
        }
    }
}
