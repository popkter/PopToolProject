import re
from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_all_combo_boxes_use_the_shared_application_style() -> None:
    sources = [path.read_text(encoding="utf-8") for path in QML_ROOT.rglob("*.qml")]
    app_combo = (QML_ROOT / "components" / "AppComboBox.qml").read_text(encoding="utf-8")

    assert sum(source.count("AppComboBox {") for source in sources) == 4
    assert sum(len(re.findall(r"(?<!App)\bComboBox\s*\{", source)) for source in sources) == 1
    assert "color: control.currentIndex === index" in app_combo
    assert "Theme.primaryContainer" in app_combo
    assert "Theme.primaryText" in app_combo
    assert "Theme.surfaceContainerHigh" in app_combo
    popup_surface = (QML_ROOT / "components" / "AppPopupSurface.qml").read_text(encoding="utf-8")
    assert "background: AppPopupSurface" in app_combo
    assert "x: -4" in popup_surface
    assert "y: -4" in popup_surface
    assert "width: parent.width + 8" in popup_surface
    assert "height: parent.height + 8" in popup_surface
    assert "Theme.darkMode" in popup_surface
