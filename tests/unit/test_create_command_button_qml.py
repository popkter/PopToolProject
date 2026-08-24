from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_create_command_button_is_an_icon_action_in_the_custom_grid_header() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    header_start = source.index("id: gridCreateCommandButton")
    header_end = source.index("id: customGridSearchField")
    header = source[header_start:header_end]

    assert 'icon: "add"' in header
    assert 'ToolTip.text: "新建命令"' in header
    assert "onClicked: window.openCommandEditorForCreate()" in header
    assert 'iconName: "add_circle"' not in source
    assert 'icon: "filter_list"' not in source


def test_compact_search_stays_in_the_search_row_and_opens_a_popup() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    header_end = source.index("id: searchField")
    button_start = source.index("id: compactSearchButton")
    popup_start = source.index("id: compactSearchPopup")
    popup_end = source.index("ListView {", popup_start)
    popup = source[popup_start:popup_end]

    assert button_start < header_end
    assert button_start > source.index("id: createCommandButton")
    assert "id: compactSearchSlot" in source
    assert (
        "visible: window.compactToolList"
        in source[source.index("id: compactSearchSlot") : button_start]
    )
    assert 'icon: "search"' in source[button_start:popup_start]
    assert "compactSearchPopup.open()" in source[button_start:popup_start]
    assert "compactSearchField.forceActiveFocus()" in source[button_start:popup_start]
    assert "window.toolListWidth = Math.max" not in source
    assert "parent: Overlay.overlay" in popup
    assert "text: window.toolSearchQuery" in popup


def test_wide_search_field_filters_directly_without_opening_the_popup() -> None:
    source = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    field_start = source.index("id: searchField")
    field_end = source.index("Popup {", field_start)
    field = source[field_start:field_end]

    assert "visible: !window.compactToolList" in field
    assert "text: window.toolSearchQuery" in field
    assert "window.toolSearchQuery = text" in field
    assert "compactSearchPopup.open()" not in field
