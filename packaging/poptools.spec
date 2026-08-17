from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules


ROOT = Path(SPECPATH).parent
SRC = ROOT / "src"
PACKAGE = SRC / "poptools"


UNUSED_QT_QML_PREFIXES = (
    "pyside6/qml/qt3d/",
    "pyside6/qml/qtcharts/",
    "pyside6/qml/qtdatavisualization/",
    "pyside6/qml/qtgraphs/",
    "pyside6/qml/qtlocation/",
    "pyside6/qml/qtmultimedia/",
    "pyside6/qml/qtpositioning/",
    "pyside6/qml/qtquick/pdf/",
    "pyside6/qml/qtquick/scene3d/",
    "pyside6/qml/qtquick/virtualkeyboard/",
    "pyside6/qml/qtquick3d/",
    "pyside6/qml/qtspatialaudio/",
    "pyside6/qml/qttexttospeech/",
)
UNUSED_CONTROL_STYLE_PREFIXES = (
    "pyside6/qml/qtquick/controls/fluentwinui3/",
    "pyside6/qml/qtquick/controls/fusion/",
    "pyside6/qml/qtquick/controls/imagine/",
    "pyside6/qml/qtquick/controls/material/",
    "pyside6/qml/qtquick/controls/universal/",
)
UNUSED_QT_BINARY_PREFIXES = (
    "pyside6/qt63d",
    "pyside6/qt6charts",
    "pyside6/qt6datavisualization",
    "pyside6/qt6graphs",
    "pyside6/qt6location",
    "pyside6/qt6multimedia",
    "pyside6/qt6pdf",
    "pyside6/qt6quick3d",
    "pyside6/qt6spatialaudio",
    "pyside6/qt6texttospeech",
    "pyside6/qt6virtualkeyboard",
)
UNUSED_CONTROL_STYLE_BINARIES = (
    "pyside6/qt6quickcontrols2fluentwinui3",
    "pyside6/qt6quickcontrols2fusion",
    "pyside6/qt6quickcontrols2imagine",
    "pyside6/qt6quickcontrols2material",
    "pyside6/qt6quickcontrols2universal",
)


def keep_qt_entry(entry):
    destination = entry[0].replace("\\", "/").lower()
    if destination.startswith(UNUSED_QT_QML_PREFIXES + UNUSED_CONTROL_STYLE_PREFIXES):
        return False
    if destination.startswith(UNUSED_QT_BINARY_PREFIXES + UNUSED_CONTROL_STYLE_BINARIES):
        return False
    if destination.startswith("pyside6/plugins/platforminputcontexts/qtvirtualkeyboard"):
        return False
    if destination.startswith("pyside6/plugins/qmltooling/"):
        return False
    if "/designer/" in destination or destination.startswith("pyside6/qml/qtquick/tooling/"):
        return False
    if destination.startswith("pyside6/resources/"):
        filename = destination.rsplit("/", 1)[-1]
        if "devtools_resources" in filename or ".debug." in filename:
            return False
    if destination.startswith("pyside6/translations/qtwebengine_locales/"):
        return destination.endswith(("/en-us.pak", "/zh-cn.pak"))
    if destination.startswith("pyside6/translations/"):
        return destination.endswith(("_en.qm", "_zh_cn.qm"))
    return True

datas = [
    (str(PACKAGE / "ui" / "qml"), "poptools/ui/qml"),
    (str(PACKAGE / "ui" / "terminal"), "poptools/ui/terminal"),
    (str(PACKAGE / "resources" / "tools"), "poptools/resources/tools"),
    (str(PACKAGE / "resources" / "python"), "poptools/resources/python"),
    (str(PACKAGE / "resources" / "vendor"), "poptools/resources/vendor"),
    (str(PACKAGE / "resources" / "fonts"), "poptools/resources/fonts"),
    (str(PACKAGE / "resources" / "icons" / "app-icon.ico"), "poptools/resources/icons"),
    (str(PACKAGE / "resources" / "icons" / "app-icon-ui.png"), "poptools/resources/icons"),
]

hiddenimports = collect_submodules("wexpect") + collect_submodules("winpty")

analysis = Analysis(
    [str(PACKAGE / "main.py")],
    pathex=[str(SRC)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=1,
)
analysis.binaries = [entry for entry in analysis.binaries if keep_qt_entry(entry)]
analysis.datas = [entry for entry in analysis.datas if keep_qt_entry(entry)]
pyz = PYZ(analysis.pure)

exe = EXE(
    pyz,
    analysis.scripts,
    analysis.binaries,
    analysis.datas,
    [],
    exclude_binaries=False,
    name="泡泡工具箱",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    icon=str(PACKAGE / "resources" / "icons" / "app-icon.ico"),
)
