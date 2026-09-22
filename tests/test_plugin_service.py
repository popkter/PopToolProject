from __future__ import annotations

import hashlib
import io
import json
import sys
import zipfile
from dataclasses import asdict
from types import SimpleNamespace

import pytest

from poptools.infrastructure import plugin_service as plugins
from poptools.infrastructure.app_updater import update_asset_name
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.plugin_service import PluginPackage, PluginService
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.paths import AppPaths, plugin_record


@pytest.fixture
def service(tmp_path, monkeypatch):
    service = PluginService(AppPaths(tmp_path))
    monkeypatch.setattr(plugins.psutil, "process_iter", lambda *args: [])
    monkeypatch.setattr(service, "_run", lambda args, cancelled: "")
    return service


def runtime(tmp_path, plugin="powershell"):
    source = tmp_path / f"source-{plugin}"
    source.mkdir(exist_ok=True)
    (source / plugins.EXECUTABLES[plugin]).write_bytes(b"executable")
    if plugin == "android":
        for name in ("adb.exe", "scrcpy-server", "SDL3.dll"):
            (source / name).write_bytes(b"file")
    return source


def package(version="7.6.3"):
    return PluginPackage(version, "https://example.test/runtime.zip", "a" * 64)


def test_install_update_uninstall_preserves_user_data(service, tmp_path):
    source = runtime(tmp_path)
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    script = scripts / "keep.py"
    script.write_text("print(1)")
    service.install("powershell", package(), source=source)
    first = service.directory("powershell")
    assert service.available("powershell")
    service.install("powershell", package("7.6.6"), source=source)
    assert service.record("powershell")["package"]["version"] == "7.6.6"
    assert not first.exists()
    service.uninstall("powershell")
    assert not service.available("powershell")
    assert service.record("powershell") == {"removed": True}
    assert script.read_text() == "print(1)"


def test_validation_failure_keeps_previous_install(service, tmp_path, monkeypatch):
    source = runtime(tmp_path)
    service.install("powershell", package(), source=source)
    previous = service.record("powershell")

    def fail(*args):
        raise RuntimeError("invalid binary")

    monkeypatch.setattr(service, "_run", fail)
    with pytest.raises(RuntimeError, match="invalid binary"):
        service.install("powershell", package("7.6.6"), source=source)
    assert service.record("powershell") == previous
    assert not list(service.paths.plugins_dir.glob("*/*/.pending"))


def test_cancel_keeps_previous(service, tmp_path):
    source = runtime(tmp_path)
    service.install("powershell", package(), source=source)
    previous = service.record("powershell")
    with pytest.raises(RuntimeError, match="取消"):
        service.install("powershell", package("7.6.6"), source=source, cancelled=lambda: True)
    assert service.record("powershell") == previous


@pytest.mark.parametrize(
    "name", ["../escape.exe", "C:/escape.exe", "..\\escape.exe", "/escape.exe"]
)
def test_rejects_archive_traversal(tmp_path, name):
    archive = tmp_path / "bad.zip"
    with zipfile.ZipFile(archive, "w") as output:
        output.writestr(name, "bad")
    with pytest.raises(ValueError, match="不安全"):
        PluginService._extract(archive, tmp_path / "out")


def test_checksum_failure_never_activates(service, monkeypatch):
    response = io.BytesIO(b"corrupted package")
    response.headers = {}
    monkeypatch.setattr(plugins.urllib.request, "urlopen", lambda *args, **kwargs: response)
    with pytest.raises(ValueError, match="校验失败"):
        service.install("powershell", package())
    assert service.record("powershell") == {}


def test_verified_download_and_extraction(service, monkeypatch):
    contents = io.BytesIO()
    with zipfile.ZipFile(contents, "w") as archive:
        archive.writestr("pwsh.exe", b"binary")
    data = contents.getvalue()
    response = io.BytesIO(data)
    response.headers = {"Content-Length": str(len(data))}
    monkeypatch.setattr(plugins.urllib.request, "urlopen", lambda *args, **kwargs: response)
    candidate = PluginPackage(
        "7.6.6", "https://example.test/pwsh.zip", hashlib.sha256(data).hexdigest()
    )
    service.install("powershell", candidate)
    assert service.executable("powershell").read_bytes() == b"binary"


def test_busy_process_and_duplicate_operation_blocked(service, tmp_path, monkeypatch):
    source = runtime(tmp_path)
    service.install("powershell", package(), source=source)
    process = SimpleNamespace(
        info={"exe": str(service.executable("powershell")), "name": "pwsh.exe"}
    )
    monkeypatch.setattr(plugins.psutil, "process_iter", lambda *args: [process])
    with pytest.raises(RuntimeError, match="正在使用"):
        service.uninstall("powershell")
    assert service.available("powershell")
    lock = service._guard("powershell")
    with lock, pytest.raises(RuntimeError, match="正在进行"):
        service.install("powershell", package(), source=source)


def test_recovery_removes_only_uncommitted_install(service, tmp_path):
    source = runtime(tmp_path)
    service.install("powershell", package(), source=source)
    active = service.directory("powershell")
    (active / ".pending").touch()  # Crash immediately after atomic activation.
    stale = active.parent / "7.6.6-abandoned"
    stale.mkdir()
    (stale / ".pending").touch()
    service.recover()
    assert active.exists()
    assert not stale.exists()


def test_removed_bundled_plugin_is_not_reseeded(service, tmp_path):
    source = runtime(tmp_path, "android")
    service.install("android", package("4.0"), source=source)
    service.uninstall("android")
    seed = service.paths.plugins_dir / "android/seed"
    seed.mkdir()
    (seed / "package.json").write_text(json.dumps(asdict(package("4.0"))))
    service.seed()
    assert not seed.exists()
    assert service.record("android") == {"removed": True}


def test_python_dependency_migration_failure_preserves_old_environment(
    service, tmp_path, monkeypatch
):
    source = runtime(tmp_path, "python")
    service.install("python", package("3.13.14"), source=source)
    previous = service.directory("python")
    executable = previous / "env/Scripts/python.exe"
    executable.parent.mkdir(parents=True)
    executable.touch()
    calls = []

    def execute(args, cancelled):
        calls.append(args)
        if "freeze" in args:
            return "incompatible-library==1.0\n"
        if "install" in args:
            raise RuntimeError("incompatible-library is unavailable")
        return ""

    monkeypatch.setattr(service, "_run", execute)
    with pytest.raises(RuntimeError, match="incompatible-library"):
        service.install("python", package("3.14.7"), source=source)
    assert service.directory("python") == previous
    assert any("venv" in args for args in calls)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows clean edition")
def test_clean_frozen_python_never_uses_host_python(tmp_path, monkeypatch):
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    environment = PythonEnvironment(AppPaths(tmp_path), ConfigStore(AppPaths(tmp_path)))
    assert not environment.ensure_ready().available
    assert environment.execution_executable() is None
    assert not (tmp_path / "python").exists()


def test_record_rejects_outside_directory(service):
    root = service.paths.plugins_dir / "python"
    root.mkdir(parents=True)
    (root / "installed.json").write_text('{"directory":"../escape"}')
    with pytest.raises(ValueError):
        plugin_record(service.paths, "python")


def test_windows_update_asset_keeps_edition():
    assert update_asset_name("win32", edition="Clean") == "PopTools-Clean-Setup.exe"
    assert update_asset_name("win32", edition="Bundled") == "PopTools-Setup.exe"
    assert update_asset_name("darwin", "arm64", "Clean") == "PopTools-macos-arm64.zip"


def test_controller_finishes_before_notifying_consumers(service, monkeypatch, qtbot):
    from poptools.viewmodels.plugin_controller import PluginController

    monkeypatch.setattr(
        "poptools.viewmodels.plugin_controller.discover_package", lambda _: package()
    )
    controller = PluginController(service)
    notifications = []
    controller.completed.connect(
        lambda plugin, success, message: notifications.append(
            (plugin, success, controller.mutating)
        )
    )
    assert controller.operate("powershell", "check")
    qtbot.waitUntil(lambda: bool(notifications))
    assert notifications == [("powershell", True, False)]
    assert not controller._jobs
    assert controller.plugins[2]["latest"] == "7.6.3"


def test_controller_blocks_mutations_during_active_tasks(service, qtbot):
    from poptools.viewmodels.plugin_controller import PluginController

    controller = PluginController(service)
    controller.busy_check = lambda _: True
    assert not controller.operate("python", "uninstall")
    assert "请先结束" in controller.plugins[0]["status"]


def test_migration_failure_keeps_legacy_runtime(service, tmp_path, monkeypatch):
    legacy = tmp_path / "old-app/runtime/python"
    legacy.mkdir(parents=True)
    (legacy / "python.exe").touch()
    (legacy / "manifest.json").write_text(
        json.dumps(
            {"version": "3.13.14", "sha256": "a" * 64, "url": "https://example.test/python.nupkg"}
        )
    )

    def fail(*args):
        raise RuntimeError("dependency migration failed")

    monkeypatch.setattr(service, "_run", fail)
    with pytest.raises(RuntimeError, match="dependency migration failed"):
        service.migrate(tmp_path / "old-app")
    assert (legacy / "python.exe").exists()
    assert not service.record("python")
