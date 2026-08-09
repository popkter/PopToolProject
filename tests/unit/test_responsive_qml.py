from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_main_window_supports_draggable_collapsible_side_panels() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "minimumWidth: 720" in source
    assert "minimumPrimaryNavWidth: 76" in source
    assert "minimumToolListWidth: 120" in source
    assert "toolListWidth = width < 900 ? minimumToolListWidth : 286" in source
    assert "compactPrimaryNav: primaryNavWidth < 176" in source
    assert "compactToolList: toolListWidth < 190" in source
    assert "id: primaryPanelResizeHandle" in source
    assert "id: toolPanelResizeHandle" in source
    assert source.count("cursorShape: Qt.SizeHorCursor") >= 4


def test_middle_panel_uses_configurable_full_height_background_without_dividers() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")

    assert "id: middlePanelBackdrop" in source
    assert "anchors.top: parent.top" in source
    assert "anchors.bottom: parent.bottom" in source
    assert "visible: !window.standbySelected" in source
    assert source.count("color: settingsController.middlePanelColor") == 1
    assert 'Layout.preferredWidth: window.toolListWidth' in source
    assert "middlePanelColorField.text = root.controller.middlePanelColor" in settings
    assert "root.controller.saveMiddlePanelColor" in settings
    assert "#RRGGBB 或 #AARRGGBB" in settings
    assert "[0-9A-Fa-f]{8}" in settings


def test_main_window_supports_compact_height() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "minimumHeight: 448" in source
    assert "height = Math.max(minimumHeight, settingsController.startupWindowHeight)" in source
    assert "compactHeight: height < 620" in source
    assert "dense: window.compactHeight" in source


def test_collapsed_navigation_items_expose_tooltips() -> None:
    for component in ("NavItem.qml", "ToolListItem.qml"):
        source = (QML_ROOT / "components" / component).read_text(encoding="utf-8")
        assert "ToolTip.visible" in source
        assert "mouseArea.containsMouse" in source

def test_standby_tool_uses_two_columns_and_refreshes_a_chinese_clock() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'label: "待机工具"' in source
    assert "visible: !window.standbySelected" in source
    assert "interval: 1000" in source
    assert "formatStandbyDateTime(new Date())" in source
    assert '["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]' in source

def test_side_panel_content_stays_within_resized_columns() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    command = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")
    nav_item = (QML_ROOT / "components" / "NavItem.qml").read_text(encoding="utf-8")
    device = (QML_ROOT / "components" / "DeviceSelector.qml").read_text(encoding="utf-8")

    assert main.count("Layout.minimumWidth: 0") >= 8
    assert main.count("clip: true") + command.count("clip: true") >= 6
    assert 'text: "泡泡工具箱"' in main
    assert 'text: "Android 开发者工具箱"' in main
    assert "elide: Text.ElideRight" in main
    assert "Layout.preferredWidth: 40" in main
    assert "Layout.minimumWidth: 40" in main
    assert "clip: true" in nav_item
    assert "Layout.minimumWidth: 0" in nav_item
    assert "elide: Text.ElideRight" in nav_item
    assert "clip: true" in device
    assert device.count("Layout.minimumWidth: 0") >= 3

def test_collapsing_primary_nav_keeps_its_vertical_alignment() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert (
        "anchors.leftMargin: window.compactHeight || window.compactPrimaryNav ? 10 : 18"
        in source
    )
    assert (
        "anchors.rightMargin: window.compactHeight || window.compactPrimaryNav ? 10 : 18"
        in source
    )
    assert "anchors.topMargin: window.compactHeight ? 10 : 18" in source
    assert "anchors.bottomMargin: window.compactHeight ? 10 : 18" in source

def test_collapsing_tool_list_keeps_search_and_content_height() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "anchors.leftMargin: window.compactToolList || window.compactHeight ? 10 : 16" in source
    assert "anchors.rightMargin: window.compactToolList || window.compactHeight ? 10 : 16" in source
    assert "anchors.topMargin: window.compactHeight ? 10 : 16" in source
    assert "anchors.bottomMargin: window.compactHeight ? 10 : 16" in source
    assert source.count("Layout.minimumHeight: 48") >= 2
    assert source.count("Layout.maximumHeight: 48") >= 2
