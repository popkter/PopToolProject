from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_custom_tools_use_a_responsive_one_to_four_column_grid() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    card = (QML_ROOT / "components" / "ToolGridItem.qml").read_text(encoding="utf-8")

    assert "id: customToolGridPanel" in main
    assert "GridView {" in main
    assert "1, Math.min(4, Math.floor(width / 240))" in main
    assert "cellWidth: width / columnCount" in main
    assert "cellHeight: 92" in main
    assert "height: 80" in main
    assert "ToolGridItem {" in main
    assert "required property string description" in card
    assert "visible: root.running" in card
    assert "Layout.preferredHeight: 20" in card
    assert "root.title + \"\\n\" + root.description" in card
    assert "onPressAndHold" in card
    assert "drag.axis: Drag.XAndYAxis" in card
    assert "row * customToolGrid.columnCount + column" in main

    def column_count(width: int) -> int:
        return max(1, min(4, width // 240))

    assert column_count(239) == 1
    assert column_count(600) == 2
    assert column_count(800) == 3
    assert column_count(1000) == 4
    assert column_count(1600) == 4
    assert column_count(2400) == 4


def test_custom_tool_card_opens_a_right_side_detail_drawer() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "onClicked: window.openCustomToolDrawer(parent.toolId)" in source
    assert "appController.selectTool(toolId)" in source
    assert "readonly property bool customToolDrawerVisible" in source
    assert 'appController.selectedTool.section === "custom"' in source
    assert "property bool customToolDrawerOpen" not in source
    assert "appController.clearToolSelection()" in source
    assert 'sequence: "Esc"' in source
    assert "enabled: window.customToolDrawerVisible && !window.applicationOverlayVisible" in source
    assert "contentPanel.parent.width" in source
    assert "- contentPanel.width - 12" in source
    assert "Easing.OutCubic" in source
    assert "onClicked: window.closeCustomToolDrawer()" in source
    assert 'ToolTip.text: "关闭详情"' in source


def test_custom_drawer_only_animates_when_its_open_state_changes() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "Behavior on x" not in source
    assert 'name: "drawerOpen"' in source
    assert 'name: "drawerClosed"' in source
    assert 'from: "drawerClosed"' in source
    assert 'to: "drawerOpen"' in source
    assert (
        "contentPanel.parent.width\n"
        "                                    - contentPanel.width - 12"
        in source
    )


def test_custom_grid_search_filters_the_shared_tool_model() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    controller = (
        Path(__file__).parents[2] / "src" / "poptools" / "viewmodels" / "app_controller.py"
    ).read_text(encoding="utf-8")

    assert "onToolSearchQueryChanged: appController.setToolSearchQuery(toolSearchQuery)" in source
    assert "id: customGridSearchField" in source
    assert "def setToolSearchQuery(self, query: str)" in controller
