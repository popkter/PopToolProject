import json
from pathlib import Path

from PySide6.QtCore import QMetaObject, QObject, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickWindow
from pytestqt.exceptions import TimeoutError as QtTimeoutError

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.paths import AppPaths, package_root
from poptools.viewmodels.settings_controller import SettingsController


def test_bundled_guide_matches_standalone_manual():
    root = Path(__file__).resolve().parents[1]
    assert (package_root() / "resources/help/guide.html").read_bytes() == (
        root / "docs/guide.html"
    ).read_bytes()


def test_guide_loads_closes_and_can_be_reopened(qapp, qtbot, tmp_path):
    paths = AppPaths(tmp_path / "data")
    store = ConfigStore(paths)
    controller = SettingsController(store, PythonEnvironment(paths, store))
    assert controller.userGuideSeen is False
    assert Path(controller.userGuideUrl.toLocalFile()).is_file()
    engine = QQmlEngine()
    engine.rootContext().setContextProperty("guideController", controller)
    component = QQmlComponent(engine)
    component.setData(
        b'''
import QtQuick
import QtQuick.Controls
import "components"
import "theme"
ApplicationWindow {
    id: window
    width: 1024; height: 800; visible: true
    Binding { target: Theme; property: "darkMode"; value: guideController.darkTheme }
    property string themeSnapshot: ""
    function inspectTheme() {
        guide.runGuideJavaScript(
            "JSON.stringify({mode: document.documentElement.dataset.appTheme, "
            + "background: getComputedStyle(document.body).backgroundColor, "
            + "radius: getComputedStyle(document.body).borderRadius, "
            + "width: document.body.offsetWidth, height: document.body.offsetHeight, "
            + "margin: getComputedStyle(document.querySelector('.page')).margin, "
            + "closeHeight: document.getElementById('guide-close').offsetHeight, "
            + "f12Blocked: !document.dispatchEvent(new KeyboardEvent('keydown', "
            + "{key: 'F12', keyCode: 123, cancelable: true})), "
            + "contextMenuBlocked: !document.dispatchEvent(new MouseEvent('contextmenu', "
            + "{button: 2, cancelable: true}))})",
            function(value) { window.themeSnapshot = value }
        )
    }
    function closeHtmlGuide() {
        guide.runGuideJavaScript("document.getElementById('guide-close').click()")
    }
    QtObject {
        id: updates
        property string updateCheckFrequency: "weekly"
        property bool canChangeUpdateChannel: true
        property bool prereleaseUpdatesEnabled: false
        property string status: ""
        property string state: "idle"
    }
    SettingsPage {
        anchors.fill: parent
        controller: guideController
        updateBackend: updates
        onUserHelpRequested: guide.open()
    }
    UserGuideDialog {
        id: guide
        controller: guideController
        parentWindow: window
    }
    Component.onCompleted: guide.open()
}
''',
        QUrl.fromLocalFile(str(package_root() / "ui/qml/GuideTest.qml")),
    )
    window = component.create()
    assert window is not None, [error.toString() for error in component.errors()]
    assert isinstance(window, QQuickWindow)
    try:
        dialog = window.findChild(QObject, "userGuideDialog")
        assert dialog is not None
        qtbot.waitUntil(lambda: dialog.property("pageLoaded") is True, timeout=20000)
        assert not dialog.property("loadFailed")
        for mode, background in [("dark", "rgb(17, 22, 30)"), ("light", "rgb(248, 250, 252)")]:
            controller.saveThemeMode(mode)

            def theme_matches(mode=mode, background=background):
                QMetaObject.invokeMethod(window, "inspectTheme")
                snapshot = window.property("themeSnapshot")
                return bool(snapshot) and json.loads(snapshot) == {
                    "mode": mode, "background": background,
                    "radius": "0px", "margin": "0px", "closeHeight": 40,
                    "width": round(dialog.property("width")),
                    "height": round(dialog.property("height")),
                    "f12Blocked": True, "contextMenuBlocked": True,
                }

            try:
                qtbot.waitUntil(theme_matches, timeout=5000)
            except QtTimeoutError:
                raise AssertionError(window.property("themeSnapshot")) from None
        assert dialog.property("width") == 900
        assert dialog.property("height") == min(840, window.height() - 24)
        web_view = window.findChild(QObject, "userGuideWebView")
        assert web_view.property("width") == dialog.property("width")
        assert web_view.property("height") == dialog.property("height")

        def no_black_pixels_outside_guide():
            # Inspect rendered pixels, not just logical QML/DOM dimensions.
            image = window.grabWindow()
            if image.isNull():
                return False
            scale_x = image.width() / window.width()
            scale_y = image.height() / window.height()
            right = round((dialog.property("x") + dialog.property("width") + 2) * scale_x)
            bottom = round((dialog.property("y") + dialog.property("height") + 2) * scale_y)
            for y in range(0, image.height(), 4):
                for x in range(0, image.width(), 4):
                    if x >= right or y >= bottom:
                        color = image.pixelColor(x, y)
                        if max(color.red(), color.green(), color.blue()) < 12:
                            return False
            return True

        qtbot.waitUntil(no_black_pixels_outside_guide, timeout=5000)
        def visual_items(item):
            yield item
            for child in item.childItems():
                yield from visual_items(child)

        items = {item.objectName(): item for item in visual_items(window.contentItem())}
        for mode in ("light", "dark", "system"):
            theme_button = items["themeChoice_" + mode]
            assert theme_button.property("height") == 48
        window.setProperty("width", 700)
        window.setProperty("height", 600)
        qtbot.waitUntil(lambda: dialog.property("width") == 676)
        assert dialog.property("height") == 576
        qtbot.waitUntil(lambda: web_view.property("width") == 676)
        assert web_view.property("height") == 576
        qtbot.waitUntil(no_black_pixels_outside_guide, timeout=5000)
        assert QMetaObject.invokeMethod(window, "closeHtmlGuide")
        qtbot.waitUntil(lambda: not dialog.property("visible"))
        assert ConfigStore(paths).user_guide_seen() is True
        help_button = window.findChild(QObject, "openUserHelpButton")
        assert help_button is not None
        update_button = window.findChild(QObject, "checkUpdateButton")
        assert abs(help_button.property("width") - update_button.property("width")) < 1
        assert help_button.property("height") == update_button.property("height") == 40
        assert help_button.parent().property("y") > update_button.parent().property("y")
        assert QMetaObject.invokeMethod(help_button, "clicked")
        qtbot.waitUntil(lambda: dialog.property("visible") is True)
        qtbot.waitUntil(lambda: dialog.property("pageLoaded") is True, timeout=20000)
        reopened_web_view = window.findChild(QObject, "userGuideWebView")
        assert reopened_web_view is not web_view
        assert reopened_web_view.property("width") == 676
        assert reopened_web_view.property("height") == 576
        qtbot.waitUntil(no_black_pixels_outside_guide, timeout=5000)
        assert controller.userGuideSeen is True
        assert QMetaObject.invokeMethod(dialog, "finishGuide")
    finally:
        window.close()
        window.deleteLater()
        engine.deleteLater()


def test_webengine_runtime_is_not_stripped_from_release():
    # Exercise the release filter without running PyInstaller's build steps.
    root = Path(__file__).resolve().parents[1]
    source = (root / "packaging/poptools.spec").read_text(encoding="utf-8")
    scope = {}
    exec(source[source.index("UNUSED_QT_QML_PREFIXES"):source.index("common_datas =")], scope)
    keep = scope["keep_qt_entry"]
    for path in (
        "PySide6/Qt6WebEngineCore.dll",
        "PySide6/QtWebEngineProcess.exe",
        "PySide6/qml/QtWebEngine/qtwebenginequickplugin.dll",
        "PySide6/resources/qtwebengine_resources.pak",
        "PySide6/resources/icudtl.dat",
        "PySide6/translations/qtwebengine_locales/en-US.pak",
        "PySide6/translations/qtwebengine_locales/zh-CN.pak",
        "PySide6/Qt/lib/QtWebEngineCore.framework/Helpers/QtWebEngineProcess.app",
    ):
        assert keep((path, "", "")), path
