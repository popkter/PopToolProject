from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules


ROOT = Path(SPECPATH).parent
SRC = ROOT / "src"
PACKAGE = SRC / "poptools"

datas = [
    (str(PACKAGE / "ui" / "qml"), "poptools/ui/qml"),
    (str(PACKAGE / "resources" / "tools"), "poptools/resources/tools"),
    (str(PACKAGE / "resources" / "vendor"), "poptools/resources/vendor"),
    (str(PACKAGE / "resources" / "scripts"), "poptools/resources/scripts"),
    (str(PACKAGE / "resources" / "fonts"), "poptools/resources/fonts"),
    (str(PACKAGE / "resources" / "icons"), "poptools/resources/icons"),
]

hiddenimports = collect_submodules("wexpect")

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
