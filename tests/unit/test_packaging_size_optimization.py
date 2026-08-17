from __future__ import annotations

import ast
from pathlib import Path

ROOT = Path(__file__).parents[2]
SPEC = ROOT / "packaging" / "poptools.spec"


def _load_keep_function():
    tree = ast.parse(SPEC.read_text(encoding="utf-8"))
    selected = [
        node
        for node in tree.body
        if isinstance(node, (ast.Assign, ast.FunctionDef))
        and (
            isinstance(node, ast.FunctionDef)
            or any(
                isinstance(target, ast.Name)
                and target.id.startswith(("UNUSED_", "keep_qt_entry"))
                for target in node.targets
            )
        )
    ]
    namespace: dict[str, object] = {}
    exec(compile(ast.Module(body=selected, type_ignores=[]), str(SPEC), "exec"), namespace)
    return namespace["keep_qt_entry"]


def test_packaging_removes_only_optional_qt_resources() -> None:
    keep = _load_keep_function()

    removed = (
        "PySide6/resources/qtwebengine_devtools_resources.pak",
        "PySide6/resources/qtwebengine_resources.debug.pak",
        "PySide6/Qt6Quick3DRuntimeRender.dll",
        "PySide6/qml/QtQuick/VirtualKeyboard/qmldir",
        "PySide6/qml/QtQuick/Controls/Material/qtquickcontrols2materialstyleplugin.dll",
        "PySide6/translations/qtwebengine_locales/fr.pak",
    )
    required = (
        "PySide6/Qt6WebEngineCore.dll",
        "PySide6/Qt6Positioning.dll",
        "PySide6/resources/qtwebengine_resources.pak",
        "PySide6/qml/QtWebEngine/qtwebenginequickplugin.dll",
        "PySide6/qml/QtQuick/Controls/Windows/qtquickcontrols2windowsstyleplugin.dll",
        "PySide6/qml/QtQuick/Controls/Basic/qtquickcontrols2basicstyleplugin.dll",
        "PySide6/translations/qtwebengine_locales/zh-CN.pak",
        "PySide6/translations/qtwebengine_locales/en-US.pak",
    )

    assert all(not keep((path, path, "DATA")) for path in removed)
    assert all(keep((path, path, "DATA")) for path in required)


def test_packaging_uses_the_optimized_ui_icon() -> None:
    spec = SPEC.read_text(encoding="utf-8")
    main = (ROOT / "src" / "poptools" / "ui" / "qml" / "Main.qml").read_text(
        encoding="utf-8"
    )

    assert '"icons" / "app-icon.ico"' in spec
    assert '"icons" / "app-icon-ui.png"' in spec
    assert 'source: Qt.resolvedUrl("../../resources/icons/app-icon-ui.png")' in main
    optimized_icon = (
        ROOT / "src" / "poptools" / "resources" / "icons" / "app-icon-ui.png"
    )
    assert optimized_icon.stat().st_size < 200_000
