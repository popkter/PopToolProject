from pathlib import Path

import poptools.viewmodels.preset_controller as preset_module
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
    assert "QtDialogs.ColorDialog" not in picker
    assert "picker.utilities.startScreenColorPicking(" in picker
    assert "picker.Window.window" in picker
    assert "function onScreenColorPicked(color)" in picker
    assert "function onScreenColorPickingCancelled()" in picker
    assert 'picker.screenPicking ? "点击屏幕取色" : "系统取色"' in picker
    assert "saturationValueCanvas" in picker
    assert "picker.selectedSaturation" in picker
    assert "picker.selectedValue" in picker
    assert "picker.selectedHue" in picker
    assert "picker.selectedAlpha" in picker
    assert "onPositionChanged" in picker
    assert 'text: "透明度"' in picker
    assert "picker.updateColorText()" in picker


def test_tray_preset_dialog_receives_live_controllers_and_exposes_recording_action() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    dialog = (QML_ROOT / "components" / "RecentToolDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "presetUtilities: presetController" in main
    assert "deviceController: androidController" in main
    assert "utilities: root.presetUtilities" in dialog
    assert "androidController: root.deviceController" in dialog
    assert 'text: root.operationRunning ? "结束录制" : "开始录制"' in dialog
    assert "onClicked: root.toggleRecording()" in dialog


def test_native_scrcpy_is_hidden_while_application_overlays_are_visible() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    terminal_dialog = (QML_ROOT / "components" / "PowerShellPluginDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "readonly property bool applicationOverlayVisible:" in main
    assert "powershellPluginDialog.visible" in main
    assert "executionCapacityDialog.visible" in main
    assert "userGuideDialogLoader.item.visible" in main
    assert "overlaysVisible: window.applicationOverlayVisible" in main
    assert "onApplicationOverlayVisibleChanged:" in main
    terminal_action = main[main.index('label: "终端"') : main.index('label: "时间"')]
    assert "window.hideScrcpyWindow()" in terminal_action
    assert "visible: settingsController.terminalEnabled" in main
    assert "developerConsoleController.ensureStarted()" in terminal_action
    assert "developerConsoleController.requestTerminalAccess()" not in terminal_action
    assert "Dialog {" in terminal_dialog
    assert "anchors.centerIn: Overlay.overlay" in terminal_dialog


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


def test_recording_uses_scrcpy_without_creating_a_desktop_window() -> None:
    controller = (
        Path(__file__).parents[2]
        / "src"
        / "poptools"
        / "viewmodels"
        / "preset_controller.py"
    ).read_text(encoding="utf-8")

    assert "_hide_window_from_taskbar(handle)" in controller
    assert "QTimer.singleShot(10, self._hide_recording_window)" in controller


def test_screen_color_picker_emits_color_and_releases_overlay(monkeypatch) -> None:
    overlays = []

    class FakeOverlay:
        def __init__(self, picked, cancelled) -> None:
            self.picked = picked
            self.cancelled = cancelled
            self.started = False
            overlays.append(self)

        def begin(self) -> None:
            self.started = True

    monkeypatch.setattr(preset_module, "ScreenColorPickerOverlay", FakeOverlay)
    controller = PresetController()
    colors: list[str] = []
    controller.screenColorPicked.connect(colors.append)

    class FakeWindow:
        def __init__(self) -> None:
            self.visible = True
            self.raised = False
            self.activated = False

        def setProperty(self, name: str, value: bool) -> None:  # noqa: N802
            assert name == "visible"
            self.visible = value

        def raise_(self) -> None:
            self.raised = True

        def requestActivate(self) -> None:  # noqa: N802
            self.activated = True

    source = FakeWindow()

    assert controller.startScreenColorPicking(source) is True  # type: ignore[arg-type]
    assert source.visible is False
    controller._begin_screen_color_picking()  # noqa: SLF001
    assert overlays[0].started is True
    assert controller.startScreenColorPicking(source) is False  # type: ignore[arg-type]

    overlays[0].picked("#12ABEF")

    assert colors == ["#12ABEF"]
    assert source.visible is True
    assert source.raised is True
    assert source.activated is True
    assert controller.startScreenColorPicking(source) is True  # type: ignore[arg-type]
