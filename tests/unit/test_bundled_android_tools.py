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


def test_packaging_collects_bundled_scrcpy_directory() -> None:
    project_root = Path(__file__).parents[2]
    spec = (project_root / "packaging" / "poptools.spec").read_text(encoding="utf-8")
    pyproject = (project_root / "pyproject.toml").read_text(encoding="utf-8")

    assert '"resources" / "vendor"' in spec
    assert '"resources/vendor/*"' in pyproject


class FakeWinFunction:
    def __init__(self, result: int = 0) -> None:
        self.result = result
        self.calls: list[tuple[object, ...]] = []
        self.argtypes: list[object] = []
        self.restype: object = None

    def __call__(self, *args: object) -> int:
        self.calls.append(args)
        return self.result


class FakeUser32:
    def __init__(self) -> None:
        self.GetWindowLongPtrW = FakeWinFunction(0x80000000)
        self.SetWindowLongPtrW = FakeWinFunction()
        # A top-level window has no previous parent, so successful SetParent
        # legitimately returns NULL and must be distinguished from an error.
        self.SetParent = FakeWinFunction()


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
