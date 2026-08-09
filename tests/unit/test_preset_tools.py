from pathlib import Path

from poptools.viewmodels.preset_controller import PresetController

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_preset_workspace_supports_json_copy_and_interactive_color_picker() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    preset = (QML_ROOT / "components" / "PresetWorkspace.qml").read_text(encoding="utf-8")
    picker = (QML_ROOT / "components" / "InteractiveColorPicker.qml").read_text(
        encoding="utf-8"
    )

    assert "PresetWorkspace {" in main
    assert "jsonOutputArea.copy()" in preset
    assert "InteractiveColorPicker {" in preset
    assert "QtDialogs.ColorDialog" in picker
    assert "colorDialog.open()" in picker
    assert 'text: "系统取色"' in picker
    assert "saturationValueCanvas" in picker
    assert "picker.selectedSaturation" in picker
    assert "picker.selectedValue" in picker
    assert "picker.selectedHue" in picker
    assert "picker.selectedAlpha" in picker
    assert "onPositionChanged" in picker
    assert 'text: "透明度"' in picker
    assert "picker.updateColorText()" in picker


def test_timestamp_conversion_supports_both_directions() -> None:
    controller = object()

    from_seconds = PresetController.convertTimestamp(controller, "0")  # type: ignore[arg-type]
    from_local_time = PresetController.convertTimestamp(  # type: ignore[arg-type]
        controller, "2026-07-29 14:30:00"
    )

    assert "本地时间：" in from_seconds
    assert "秒：0" in from_seconds
    assert "毫秒：0" in from_seconds
    assert "本地时间：2026-07-29 14:30:00" in from_local_time
    assert "秒：" in from_local_time
    assert "毫秒：" in from_local_time


def test_json_conversion_formats_compacts_and_reports_locations() -> None:
    controller = object()

    pretty = PresetController.formatJson(  # type: ignore[arg-type]
        controller,
        '{"message":"你好","items":[1,2]}',
        False,
    )
    compact = PresetController.formatJson(  # type: ignore[arg-type]
        controller,
        pretty,
        True,
    )
    invalid = PresetController.formatJson(  # type: ignore[arg-type]
        controller,
        '{\n  "broken":\n}',
        False,
    )

    assert '\n  "message": "你好"' in pretty
    assert compact == '{"message":"你好","items":[1,2]}'
    assert "JSON 错误：第 3 行，第 1 列" in invalid
