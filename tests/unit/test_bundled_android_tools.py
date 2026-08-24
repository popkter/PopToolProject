import json
import os
from pathlib import Path

import pytest

import poptools.infrastructure.scrcpy_controller as scrcpy_module
from poptools.infrastructure.android_device_service import find_adb_executable
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import (
    AppPaths,
    bundled_adb_path,
    bundled_android_tools_dir,
    bundled_scrcpy_path,
    prepare_bundled_android_tools,
    resource_path,
)


def test_official_scrcpy_distribution_is_bundled_and_materialized(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("POPTOOLS_ANDROID_TOOLS_DIR", raising=False)
    monkeypatch.setattr("poptools.paths.sys.platform", "win32")
    monkeypatch.setattr("poptools.paths.platform.machine", lambda: "x86_64")
    vendor = resource_path("vendor")
    manifest = json.loads((vendor / "scrcpy-manifest.json").read_text(encoding="utf-8"))
    assert manifest["version"] == "4.0"
    assert manifest["sha256"] == (
        "75dbeb5b00e6f64292f26f70900ae55ca397786bdfb0b9bbeb481a0549047457"
    )
    assert (vendor / manifest["archive"]).is_file()
    assert (vendor / "scrcpy-LICENSE.txt").is_file()

    app_paths = AppPaths(tmp_path / "data")
    directory = prepare_bundled_android_tools(app_paths)
    required = {
        "adb.exe",
        "AdbWinApi.dll",
        "AdbWinUsbApi.dll",
        "scrcpy.exe",
        "scrcpy-server",
        "SDL3.dll",
        "LICENSE.txt",
        "manifest.json",
    }
    assert required <= {path.name for path in directory.iterdir()}
    assert prepare_bundled_android_tools(app_paths) == directory
    assert directory.parent == app_paths.runtime_dir
    assert bundled_android_tools_dir() == directory
    assert bundled_adb_path().is_file()
    assert bundled_scrcpy_path().is_file()
    assert find_adb_executable() == str(bundled_adb_path())


def test_scrcpy_tool_uses_global_android_device(tmp_path: Path) -> None:
    registry = ToolRegistry(resource_path("tools"), JsonToolRepository(AppPaths(tmp_path)))

    tool = registry.get("preset.android.scrcpy")

    assert tool is not None
    assert tool.section.value == "preset"
    assert tool.editable is False
    assert tool.executor.command == "scrcpy"
    assert set(tool.executor.requirements) == {"adb", "android_device"}
    assert tool.presentation.output_mode == "embedded"


def test_projection_window_starts_offscreen_until_it_is_embedded() -> None:
    arguments = scrcpy_module._projection_arguments(  # noqa: SLF001
        "device-serial", "projection-window", embed=True
    )

    assert "--window-x=-32000" in arguments
    assert "--window-y=-32000" in arguments
    assert "--window-width=1" in arguments
    assert "--window-height=1" in arguments


def test_macos_projection_uses_a_normal_top_level_window() -> None:
    arguments = scrcpy_module._projection_arguments(  # noqa: SLF001
        "device-serial", "projection-window", embed=False
    )

    assert "--no-audio" in arguments
    assert not any(argument.startswith("--window-x=") for argument in arguments)


def test_projection_window_is_hidden_before_native_embedding(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    controller = scrcpy_module.ScrcpyController()

    class FakeProcess:
        process_id = 321

    class FakeHostWindow:
        @staticmethod
        def winId() -> int:
            return 654

    calls: list[tuple[object, ...]] = []
    controller._process = FakeProcess()  # type: ignore[assignment]  # noqa: SLF001
    controller._host_window = FakeHostWindow()  # type: ignore[assignment]  # noqa: SLF001
    controller._window_title = "projection-window"  # noqa: SLF001
    monkeypatch.setattr(scrcpy_module, "_find_process_window", lambda *_args: 123)
    monkeypatch.setattr(
        scrcpy_module,
        "_show_window",
        lambda handle, visible: calls.append(("show", handle, visible)),
    )
    monkeypatch.setattr(
        scrcpy_module,
        "_embed_window",
        lambda child, parent: calls.append(("embed", child, parent)) or True,
    )
    monkeypatch.setattr(
        controller, "_sync_embedded_window", lambda: calls.append(("sync",))
    )

    controller._try_embed_window()  # noqa: SLF001

    assert calls[:3] == [
        ("show", 123, False),
        ("embed", 123, 654),
        ("sync",),
    ]


def test_packaging_collects_bundled_scrcpy_directory() -> None:
    project_root = Path(__file__).parents[2]
    spec = (project_root / "packaging" / "poptools.spec").read_text(encoding="utf-8")
    pyproject = (project_root / "pyproject.toml").read_text(encoding="utf-8")

    assert '"resources" / "vendor"' in spec
    assert '"resources/vendor/*"' in pyproject
    assert '"resources" / "python"' in spec
    assert '"resources/python/*.py"' in pyproject


class FakeWinFunction:
    def __init__(self, result: int = 0) -> None:
        self.result = result
        self.calls: list[tuple[object, ...]] = []
        self.argtypes: list[object] = []
        self.restype: object = None

    def __call__(self, *args: object) -> int:
        self.calls.append(args)
        return self.result


class CallbackWinFunction(FakeWinFunction):
    def __init__(self, callback) -> None:
        super().__init__()
        self.callback = callback

    def __call__(self, *args: object) -> int:
        self.calls.append(args)
        return int(self.callback(*args))


class FakeUser32:
    def __init__(self) -> None:
        self.GetWindowLongPtrW = FakeWinFunction(0x80000000)
        self.SetWindowLongPtrW = FakeWinFunction()
        self.SetWindowPos = FakeWinFunction(1)
        self.ShowWindow = FakeWinFunction(1)
        # A top-level window has no previous parent, so successful SetParent
        # legitimately returns NULL and must be distinguished from an error.
        self.SetParent = FakeWinFunction()


@pytest.mark.skipif(os.name != "nt", reason="Windows native hosting only")
def test_visible_projection_window_is_found_directly_by_its_unique_title(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    title = "projection-window"

    class FindWindowUser32:
        def __init__(self) -> None:
            self.FindWindowW = FakeWinFunction(123)
            self.IsWindowVisible = FakeWinFunction(1)
            self.GetWindowThreadProcessId = CallbackWinFunction(
                self._write_process_id
            )

        @staticmethod
        def _write_process_id(_handle, process_id) -> int:
            process_id._obj.value = 321
            return 1

    user32 = FindWindowUser32()
    monkeypatch.setattr(scrcpy_module, "_user32", lambda: user32)

    handle = scrcpy_module._find_process_window(321, title)  # noqa: SLF001

    assert handle == 123
    assert user32.FindWindowW.calls == [(None, title)]


@pytest.mark.skipif(os.name != "nt", reason="Windows native hosting only")
def test_hidden_scrcpy_startup_window_is_not_embedded(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class HiddenWindowUser32:
        def __init__(self) -> None:
            self.FindWindowW = FakeWinFunction(123)
            self.IsWindowVisible = FakeWinFunction(0)

    monkeypatch.setattr(scrcpy_module, "_user32", HiddenWindowUser32)

    handle = scrcpy_module._find_process_window(321, "projection-window")  # noqa: SLF001

    assert handle == 0


def test_destroyed_startup_window_is_replaced_by_the_final_video_window(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    controller = scrcpy_module.ScrcpyController()

    class FakeProcess:
        process_id = 321

    class FakeHostWindow:
        @staticmethod
        def winId() -> int:
            return 654

    calls: list[tuple[object, ...]] = []
    controller._process = FakeProcess()  # type: ignore[assignment]  # noqa: SLF001
    controller._host_window = FakeHostWindow()  # type: ignore[assignment]  # noqa: SLF001
    controller._scrcpy_window = 111  # noqa: SLF001
    controller._window_title = "projection-window"  # noqa: SLF001
    monkeypatch.setattr(scrcpy_module, "_is_window", lambda _handle: False)
    monkeypatch.setattr(scrcpy_module, "_find_process_window", lambda *_args: 222)
    monkeypatch.setattr(scrcpy_module, "_show_window", lambda *_args: None)
    monkeypatch.setattr(
        scrcpy_module,
        "_embed_window",
        lambda child, parent: calls.append(("embed", child, parent)) or True,
    )
    monkeypatch.setattr(
        controller, "_sync_embedded_window", lambda: calls.append(("sync",))
    )

    controller._try_embed_window()  # noqa: SLF001

    assert controller._scrcpy_window == 222  # noqa: SLF001
    assert calls == [("embed", 222, 654), ("sync",)]


@pytest.mark.skipif(os.name != "nt", reason="Windows native hosting only")
def test_native_window_embedding_accepts_null_previous_parent(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user32 = FakeUser32()
    monkeypatch.setattr(scrcpy_module, "_user32", lambda: user32)

    embedded = scrcpy_module._embed_window(0x123456789, 0x987654321)  # noqa: SLF001

    assert embedded is True
    assert user32.SetParent.calls == [(0x123456789, 0x987654321)]
    _child, _index, style = user32.SetWindowLongPtrW.calls[0]
    assert int(style) & 0x40000000
    assert not int(style) & 0x80000000


@pytest.mark.skipif(os.name != "nt", reason="Windows taskbar integration only")
def test_recording_window_is_hidden_and_marked_as_tool_window(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user32 = FakeUser32()
    user32.GetWindowLongPtrW.result = 0x00040000
    monkeypatch.setattr(scrcpy_module, "_user32", lambda: user32)

    hidden = scrcpy_module._hide_window_from_taskbar(0x123456789)  # noqa: SLF001

    assert hidden is True
    assert user32.ShowWindow.calls == [(0x123456789, 0)]
    _window, index, style = user32.SetWindowLongPtrW.calls[0]
    assert index == -20
    assert int(style) & 0x00000080
    assert not int(style) & 0x00040000
