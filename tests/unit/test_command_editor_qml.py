from pathlib import Path

QML_COMPONENTS = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml" / "components"


def test_command_editor_uses_one_scrollable_script_editor_for_create_and_edit() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")

    assert source.count("ScrollBar.horizontal.policy: ScrollBar.AsNeeded") >= 1
    assert source.count("ScrollBar.vertical.policy: ScrollBar.AsNeeded") >= 2
    assert "function openForCreate()" in source
    assert "function openForEdit()" in source
    assert "model: root.commandKinds" in source
    assert "scriptParts.push(executor.args[index])" in source
    assert "参数列表" not in source
    assert "argsArea" not in source
    assert "editorPage" not in source
    assert "editKinds" not in source
    assert "createKinds" not in source


def test_command_editor_only_offers_supported_script_kinds() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")

    assert '{ "label": "PowerShell", "value": "powershell" }' in source
    assert '{ "label": "Bash", "value": "bash" }' in source
    assert '{ "label": "BAT 脚本", "value": "batch" }' in source
    assert '"value": "process"' not in source
    assert '{ "label": "Python", "value": "python" }' in source
    assert '"value": "url"' not in source
    assert "恢复默认" not in source
    assert "预置命令" not in source


def test_command_editor_can_choose_and_restore_custom_tool_icons() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")

    assert 'property string selectedIcon: "terminal"' in source
    assert 'id: titleField' in source
    assert 'leftPadding: 64' in source
    assert 'id: iconButton' in source
    assert 'text: "命令图标"' not in source
    assert "model: root.commandIcons" in source
    assert source.count('{ "label":') >= 100
    assert '{ "label": "安卓手机", "value": "phone_android" }' in source
    assert '{ "label": "调试", "value": "bug_report" }' in source
    assert '{ "label": "云上传", "value": "cloud_upload" }' in source
    assert "tool.presentation.icon" in source
    assert "onClicked: iconPopup.open()" in source
    assert "icon: root.selectedIcon" in source
    assert "root.selectedIcon = iconChoice.modelData.value" in source
    assert "iconPopup.close()" in source
    assert source.count("selectedIcon)") >= 2

def test_command_description_matches_title_field_height() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")
    title = source[source.index("id: titleField") : source.index("id: iconButton")]
    description = source[
        source.index("id: descriptionField") : source.index('placeholderText: "简要说明命令用途"')
    ]

    assert "Layout.preferredHeight: 50" in title
    assert "Layout.preferredHeight: 50" in description

def test_device_selector_exposes_global_device_context() -> None:
    source = (QML_COMPONENTS / "DeviceSelector.qml").read_text(encoding="utf-8")

    assert "全局 Android 设备" in source
    assert "controller.selectAndroidDevice" in source


def test_device_popup_matches_selector_and_wraps_up_to_three_devices() -> None:
    source = (QML_COMPONENTS / "DeviceSelector.qml").read_text(encoding="utf-8")

    assert "width: root.width" in source
    assert "Math.min(3, root.controller.androidDevices.length)" in source
    assert "devicePopup.contentItem.implicitHeight" in source
    assert "implicitHeight: emptyColumn.implicitHeight + 28" in source
    assert "readonly property int popupGap: 8" in source
    assert "point.y - devicePopup.height - root.popupGap" in source
    assert "font.pixelSize: 13" in source
    assert "font.pixelSize: 12" in source
    assert "root.mapToItem(Overlay.overlay, 0, 0)" in source
    assert "background: AppPopupSurface { }" in source
    assert "设备列表每 5 秒自动刷新" not in source
    assert source.count("horizontalAlignment: Text.AlignHCenter") >= 3
    assert 'icon: devicePopup.opened ? "expand_less" : "expand_more"' in source


def test_command_editor_footer_preserves_bottom_rounding() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")
    footer = source[source.index("Layout.preferredHeight: 76") :]

    assert "radius: 22" in footer
    assert "anchors.top: parent.top" in footer
    assert "height: 1" in footer


def test_command_editor_shrinks_script_area_and_keeps_form_scrollable() -> None:
    source = (QML_COMPONENTS / "CommandEditorDialog.qml").read_text(encoding="utf-8")
    form_scroll = source[
        source.index("id: formScroll") : source.index("Layout.preferredHeight: 76")
    ]

    assert "ColumnLayout {" in form_scroll
    assert "width: formScroll.availableWidth" in form_scroll
    assert "Layout.minimumHeight: 140" in form_scroll
    assert "Layout.preferredHeight: Math.max(140, Math.min(292, root.height - 428))" in form_scroll
    assert "ScrollBar.vertical.policy: ScrollBar.AsNeeded" in form_scroll


def test_device_popup_switches_to_icons_when_narrow() -> None:
    source = (QML_COMPONENTS / "DeviceSelector.qml").read_text(encoding="utf-8")

    assert "root.compact || devicePopup.width < 220" in source
    assert "visible: !root.popupIconOnly" in source
    assert '? "phonelink_ring" : "smartphone"' in source
    assert "rowMouse.containsMouse || deviceRow.revealClickedName" in source
    assert "deviceRow.modelData.label" in source
    assert "clickedNameTimer.restart()" in source
