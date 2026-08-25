from pathlib import Path


TERMINAL_ROOT = (
    Path(__file__).parents[2] / "src" / "poptools" / "ui" / "terminal"
)


def test_terminal_hides_the_native_scrollbar_without_disabling_scrollback() -> None:
    css = (TERMINAL_ROOT / "terminal.css").read_text(encoding="utf-8")
    xterm_css = (TERMINAL_ROOT / "xterm.css").read_text(encoding="utf-8")

    assert "#terminal .xterm-viewport" in css
    assert "scrollbar-width: none" in css
    assert "::-webkit-scrollbar" in css
    assert "overflow-y: scroll" in xterm_css


def test_terminal_coalesces_visibility_and_resize_fits() -> None:
    source = (TERMINAL_ROOT / "terminal-source.js").read_text(encoding="utf-8")
    bundle = (TERMINAL_ROOT / "terminal.js").read_text(encoding="utf-8")

    assert "let pendingFitFrame = 0" in source
    assert "cancelAnimationFrame(pendingFitFrame)" in source
    assert "pendingFitFrame = requestAnimationFrame" in source
    assert "bounds.width <= 32 || bounds.height <= 32" in source
    assert "requestAnimationFrame" in bundle
    assert "getBoundingClientRect" in bundle
