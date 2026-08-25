from pathlib import Path


QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_primary_pages_share_the_same_page_header_component() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    terminal = (QML_ROOT / "components" / "DeveloperConsole.qml").read_text(
        encoding="utf-8"
    )
    header = (QML_ROOT / "components" / "WorkspacePageHeader.qml").read_text(
        encoding="utf-8"
    )

    assert main.count("WorkspacePageHeader {") >= 2
    assert "WorkspacePageHeader {" in terminal
    assert "required property string title" in header
    assert "required property string description" in header
    assert "default property alias actions: actionRow.children" in header


def test_preset_header_spans_above_its_two_column_workspace() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "id: presetPageHeader" in main
    assert 'title: "预设功能"' in main
    assert 'text: "功能列表"' not in main
    assert "pageWorkspaceTop:" in main
    assert "anchors.topMargin: window.pageWorkspaceTop" in main
    assert "presetMode ? window.pageWorkspaceTop : 0" in main


def test_each_page_keeps_its_expected_workspace_content() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    terminal = (QML_ROOT / "components" / "DeveloperConsole.qml").read_text(
        encoding="utf-8"
    )

    assert "id: customGridSearchField" in main
    assert "id: customToolGrid" in main
    assert "id: toolList" in main
    assert "id: workspaceLoader" in main
    assert "id: terminalTabRow" in terminal
    assert "id: terminalView" in terminal
