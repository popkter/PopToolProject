from __future__ import annotations

from poptools.viewmodels import platform_ui_controller as platform_ui_module
from poptools.viewmodels.platform_ui_controller import PlatformUiController


def test_native_tooltips_are_only_enabled_on_macos(monkeypatch) -> None:
    controller = PlatformUiController()

    monkeypatch.setattr(platform_ui_module.sys, "platform", "darwin")
    assert controller.nativeWindowFrameEnabled is True
    assert controller.nativeToolTipsEnabled is True

    monkeypatch.setattr(platform_ui_module.sys, "platform", "win32")
    assert controller.nativeWindowFrameEnabled is False
    assert controller.nativeToolTipsEnabled is False


def test_native_tooltip_escapes_text_and_preserves_line_breaks(monkeypatch) -> None:
    controller = PlatformUiController()
    calls: list[tuple] = []
    monkeypatch.setattr(platform_ui_module.sys, "platform", "darwin")
    monkeypatch.setattr(
        platform_ui_module.QToolTip,
        "showText",
        lambda *arguments: calls.append(arguments),
    )

    controller.showNativeToolTip("ADB <device>\n已连接", 120, 240, 1800)

    assert len(calls) == 1
    position, text, widget, rect, timeout = calls[0]
    assert (position.x(), position.y()) == (120, 240)
    assert "ADB &lt;device&gt;<br>已连接" in text
    assert widget is None
    assert rect.isNull()
    assert timeout == 1800


def test_native_tooltip_bridge_is_noop_off_macos(monkeypatch) -> None:
    controller = PlatformUiController()
    calls: list[tuple] = []
    monkeypatch.setattr(platform_ui_module.sys, "platform", "linux")
    monkeypatch.setattr(
        platform_ui_module.QToolTip,
        "showText",
        lambda *arguments: calls.append(arguments),
    )

    controller.showNativeToolTip("不会显示", 1, 2, -1)

    assert calls == []
