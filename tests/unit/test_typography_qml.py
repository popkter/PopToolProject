import re
from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_theme_defines_the_shared_typography_scale() -> None:
    theme = (QML_ROOT / "theme" / "Theme.qml").read_text(encoding="utf-8")

    expected_roles = {
        "fontDisplay": 40,
        "fontPageTitle": 30,
        "fontTitleLarge": 24,
        "fontDialogTitle": 22,
        "fontSectionTitle": 20,
        "fontComponentTitle": 16,
        "fontButton": 16,
        "fontBody": 14,
        "fontLabel": 13,
        "fontSupporting": 13,
        "fontCode": 13,
        "fontCaption": 12,
        "fontMicro": 10,
    }
    for role, size in expected_roles.items():
        assert f"readonly property int {role}: {size}" in theme


def test_qml_text_uses_theme_typography_roles_instead_of_local_sizes() -> None:
    numeric_size = re.compile(r"font\.pixelSize:\s*\d+")

    for qml_file in QML_ROOT.rglob("*.qml"):
        source = qml_file.read_text(encoding="utf-8")
        assert numeric_size.search(source) is None, qml_file


def test_primary_surfaces_share_consistent_heading_roles() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    terminal = (QML_ROOT / "components" / "DeveloperConsole.qml").read_text(
        encoding="utf-8"
    )
    page_header = (QML_ROOT / "components" / "WorkspacePageHeader.qml").read_text(
        encoding="utf-8"
    )
    grid_item = (QML_ROOT / "components" / "ToolGridItem.qml").read_text(
        encoding="utf-8"
    )
    button = (QML_ROOT / "components" / "PrimaryButton.qml").read_text(
        encoding="utf-8"
    )

    assert main.count("Theme.fontPageTitle") >= 2
    assert "WorkspacePageHeader" in terminal
    assert "font.pixelSize: root.compact ? Theme.fontTitleLarge : Theme.fontPageTitle" in page_header
    assert "font.pixelSize: Theme.fontComponentTitle" in grid_item
    assert "font.pixelSize: Theme.fontButton" in button
