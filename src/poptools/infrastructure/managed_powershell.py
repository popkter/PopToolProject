"""Compatibility facade for terminal callers; storage belongs to PluginService."""

from types import SimpleNamespace

from poptools.infrastructure.plugin_service import PluginService, discover_package


class ManagedPowerShell:
    def __init__(self, service: PluginService):
        self.service = service

    @property
    def package(self):
        return SimpleNamespace(
            version=self.service.record("powershell").get("package", {}).get("version", "7")
        )

    @property
    def install_directory(self):
        return self.service.directory("powershell") or self.service.paths.powershell_plugin_dir

    @property
    def executable(self):
        return self.service.executable("powershell")

    def is_installed(self):
        return self.service.available("powershell")

    def install(self, progress=None):
        self.service.install(
            "powershell", discover_package("powershell"), progress or (lambda _: None)
        )
        return self.executable
