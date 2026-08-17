from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_main_window_supports_draggable_collapsible_side_panels() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "minimumWidth: 960" in source
    assert "minimumPrimaryNavWidth: 76" in source
    assert "minimumToolListWidth: 120" in source
    assert "minimumContentWidth: 480" in source
    assert "toolListWidth = width < 900 ? minimumToolListWidth : 286" in source
    assert "compactPrimaryNav: primaryNavWidth < 176" in source
    assert "compactToolList: toolListWidth < 190" in source
    assert "id: primaryPanelResizeHandle" in source
    assert "id: toolPanelResizeHandle" in source
    assert source.count("cursorShape: Qt.SizeHorCursor") >= 4


def test_middle_panel_uses_configurable_full_height_background_without_dividers() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")

    assert "readonly property color middlePanelColor" in source
    assert "id: middlePanelBackground" in source
    assert "color: window.middlePanelColor" in source
    assert "visible: !window.standbySelected" in source
    assert source.count("settingsController.middlePanelColor") == 2
    assert "Layout.preferredWidth: window.standbySelected || window.developerSelected" in source
    assert "? 0 : window.toolListWidth" in source
    assert "middlePanelColorField.text = root.controller.middlePanelColor" in settings
    assert "root.controller.saveMiddlePanelColor" in settings
    assert "#RRGGBB 或 #AARRGGBB" in settings
    assert "[0-9A-Fa-f]{8}" in settings


def test_main_window_supports_compact_height() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "minimumHeight: 720" in source
    assert "minimumContentHeight: 480" in source
    assert "width: Math.max(minimumWidth, Math.round(Screen.width * 0.8))" in source
    assert "height: Math.max(minimumHeight, Math.round(Screen.height * 0.8))" in source
    assert "visible: !window.standbySelected && !window.developerSelected" in source
    assert source.count("color: window.middlePanelColor") == 1
    assert "compactHeight: height < 620" in source
    assert "dense: window.compactHeight" in source
    assert "Qt.callLater(function () { window.releaseResources() })" in source
    assert "active: window.visible" in source


def test_third_column_has_a_hard_minimum_size() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    content_start = source.index("id: contentPanel")
    content_panel = source[content_start : content_start + 420]
    assert "Layout.minimumWidth: window.minimumContentWidth" in content_panel
    assert "Layout.minimumHeight: window.minimumContentHeight" in content_panel
    assert "width - minimumToolListWidth - minimumContentWidth" in source
    assert "width - primaryNavWidth - minimumContentWidth" in source


def test_low_frequency_dialogs_are_loaded_on_demand() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    for loader_id in (
        "settingsDialogLoader",
        "commandEditorDialogLoader",
        "deleteCommandDialogLoader",
        "confirmRunDialogLoader",
        "pythonDoctorDialogLoader",
        "userGuideDialogLoader",
    ):
        loader_start = source.index(f"id: {loader_id}")
        loader = source[loader_start - 30 : loader_start + 120]
        assert "Loader {" in loader
        assert "active: false" in loader


def test_collapsed_navigation_items_expose_tooltips() -> None:
    for component in ("NavItem.qml", "ToolListItem.qml"):
        source = (QML_ROOT / "components" / component).read_text(encoding="utf-8")
        assert "ToolTip.visible" in source
        assert "mouseArea.containsMouse" in source

def test_standby_tool_uses_two_columns_and_refreshes_a_chinese_clock() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'label: "时间"' in source
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
    assert 'label: "客制"' in main
    assert 'iconName: "build"' in main
    assert 'label: "预设"' in main
    assert 'iconName: "widgets"' in main
    assert "onDoubleClicked: window.addMeritBurst()" in main
    assert 'text: "功德 +1"' in main
    assert "meritBurstModel.append({" in main
    assert "model: meritBurstModel" in main
    assert "required property string burstId" in main
    assert "meritClickCooldown.running" in main
    assert "meritBurstModel.count >= 12" in main
    assert "expiresAt: Date.now() + 1250" in main
    assert "x: window.primaryNavWidth / 2 + offsetX" in main
    assert "offsetY: Math.round((Math.random() - 0.5) * 36)" in main
    assert "settingsController.addMerit()" in main
    assert '"累计功德 +" + settingsController.meritCount' in main
    assert "horizontalAlignment: Text.AlignHCenter" in main
    assert "visible: meritBurstModel.count > 0" in main
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
        "anchors.leftMargin: window.compactHeight || window.compactPrimaryNav ? 8 : 16"
        in source
    )
    assert (
        "anchors.rightMargin: window.compactHeight || window.compactPrimaryNav ? 8 : 16"
        in source
    )
    assert "anchors.topMargin: window.compactHeight ? 8 : 16" in source
    assert "anchors.bottomMargin: window.compactHeight ? 8 : 16" in source

def test_collapsing_tool_list_keeps_search_and_content_height() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "anchors.leftMargin: window.compactToolList || window.compactHeight ? 8 : 16" in source
    assert "anchors.rightMargin: window.compactToolList || window.compactHeight ? 8 : 16" in source
    assert "anchors.topMargin: window.compactHeight ? 8 : 16" in source
    assert "anchors.bottomMargin: window.compactHeight ? 8 : 16" in source
    assert source.count("Layout.minimumHeight: 48") >= 2
    assert source.count("Layout.maximumHeight: 48") >= 2
