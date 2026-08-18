from pathlib import Path
import platform
import re
import sys

from PyInstaller.utils.hooks import collect_submodules


ROOT = Path(SPECPATH).parent
SRC = ROOT / "src"
PACKAGE = SRC / "poptools"
PYPROJECT = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
APP_VERSION = re.search(r'(?m)^version\s*=\s*"([^"]+)"', PYPROJECT).group(1)
BUILD_VERSION_FILE = PACKAGE / "_build_version.py"
BUILD_VERSION_TEXT = (
    BUILD_VERSION_FILE.read_text(encoding="utf-8")
    if BUILD_VERSION_FILE.is_file()
    else ""
)
BUILD_VERSION_MATCH = re.search(r"(\d{4})-(\d{2})-(\d{2})_", BUILD_VERSION_TEXT)
BUNDLE_VERSION = (
    "".join(BUILD_VERSION_MATCH.groups()) if BUILD_VERSION_MATCH else "1"
)


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
    "pyside6/qml/qtquick/controls/macos/",
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
    "pyside6/qt6quickcontrols2macos",
    "pyside6/qt6quickcontrols2material",
    "pyside6/qt6quickcontrols2universal",
)


def keep_qt_entry(entry):
    destination = entry[0].replace("\\", "/").lower()
    destination = destination.replace("pyside6/qt/qml/", "pyside6/qml/")
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

common_datas = [
    (str(PACKAGE / "ui" / "qml"), "poptools/ui/qml"),
    (str(PACKAGE / "ui" / "terminal"), "poptools/ui/terminal"),
    (str(PACKAGE / "resources" / "tools"), "poptools/resources/tools"),
    (str(PACKAGE / "resources" / "python"), "poptools/resources/python"),
    (str(PACKAGE / "resources" / "fonts"), "poptools/resources/fonts"),
    (str(PACKAGE / "resources" / "icons" / "app-icon-ui.png"), "poptools/resources/icons"),
]

vendor = PACKAGE / "resources" / "vendor"
python_vendor = vendor / "python"
machine = platform.machine().lower()
architecture = "arm64" if machine in {"arm64", "aarch64"} else "x64"
if sys.platform == "darwin":
    scrcpy_manifest = vendor / f"scrcpy-manifest-macos-{architecture}.json"
    python_manifest = python_vendor / f"python-runtime-macos-{architecture}.json"
    icon_file = PACKAGE / "resources" / "icons" / "app-icon.png"
    runtime_icon_file = icon_file
    hiddenimports = []
else:
    scrcpy_manifest = vendor / "scrcpy-manifest.json"
    python_manifest = python_vendor / "python-runtime.json"
    icon_file = PACKAGE / "resources" / "icons" / "app-icon.ico"
    runtime_icon_file = icon_file
    hiddenimports = collect_submodules("wexpect") + collect_submodules("winpty")

import json

scrcpy_package = vendor / json.loads(scrcpy_manifest.read_text(encoding="utf-8"))["archive"]
python_package = python_vendor / json.loads(python_manifest.read_text(encoding="utf-8"))["file"]
vendor_datas = [
    (str(vendor / "scrcpy-LICENSE.txt"), "poptools/resources/vendor"),
    (str(scrcpy_manifest), "poptools/resources/vendor"),
    (str(scrcpy_package), "poptools/resources/vendor"),
    (str(python_vendor / "PYTHON-LICENSE.txt"), "poptools/resources/vendor/python"),
    (str(python_manifest), "poptools/resources/vendor/python"),
    (str(python_package), "poptools/resources/vendor/python"),
]
if sys.platform == "win32":
    vendor_datas.append(
        (str(vendor / "powershell-plugin.json"), "poptools/resources/vendor")
    )
datas = [
    *common_datas,
    *vendor_datas,
    (str(runtime_icon_file), "poptools/resources/icons"),
]

analysis = Analysis(
    [str(PACKAGE / "main.py")],
    pathex=[str(SRC)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["mypy", "pytest", "ruff", "PIL", "PyInstaller"],
    noarchive=False,
    optimize=1,
)
analysis.binaries = [entry for entry in analysis.binaries if keep_qt_entry(entry)]
analysis.datas = [entry for entry in analysis.datas if keep_qt_entry(entry)]
pyz = PYZ(analysis.pure)

exe = EXE(
    pyz,
    analysis.scripts,
    analysis.binaries if sys.platform == "win32" else [],
    analysis.datas if sys.platform == "win32" else [],
    [],
    exclude_binaries=sys.platform == "darwin",
    name="泡泡工具箱",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    icon=str(icon_file),
)

if sys.platform == "darwin":
    collected = COLLECT(
        exe,
        analysis.binaries,
        analysis.datas,
        strip=False,
        upx=False,
        name="泡泡工具箱",
    )
    app = BUNDLE(
        collected,
        name="泡泡工具箱.app",
        icon=str(icon_file),
        bundle_identifier="com.poptools.toolbox",
        info_plist={
            "CFBundleDisplayName": "泡泡工具箱",
            "CFBundleShortVersionString": APP_VERSION,
            "CFBundleVersion": BUNDLE_VERSION,
            "NSHighResolutionCapable": True,
            "LSMinimumSystemVersion": "12.0",
        },
    )
