from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_android_device_selector_is_global_and_above_settings() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    selector = (QML_ROOT / "components" / "DeviceSelector.qml").read_text(encoding="utf-8")

    device_index = main.index("id: globalDeviceSelector")
    settings_index = main.index('label: "设置"')
    selector_start = main.rfind("DeviceSelector {", 0, device_index)
    selector_block = main[selector_start:settings_index]

    assert main.count("id: globalDeviceSelector") == 1
    assert device_index < settings_index
    assert "visible:" not in selector_block
    assert "compact: window.compactPrimaryNav" in main
    assert "width: root.width" in selector
    assert 'background: AppPopupSurface { }' in selector
