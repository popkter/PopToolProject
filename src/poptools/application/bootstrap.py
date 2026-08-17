"""Composition root for the desktop application.

The UI entry point should only deal with Qt lifecycle and presentation wiring.
All concrete adapters are assembled here so that controllers can be reused by
tests and future frontends without duplicating application construction.
"""

from __future__ import annotations

from dataclasses import dataclass

from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.json_tool_repository import JsonToolRepository
from poptools.infrastructure.python_environment import PythonEnvironment
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.paths import AppPaths, resource_path
from poptools.runners import ExecutionCoordinator, ExecutionManager
from poptools.viewmodels import (
    AndroidController,
    AppController,
    DeveloperConsoleController,
    PresetController,
    SettingsController,
)


@dataclass
class ApplicationComponents:
    """Long-lived application services and view models.

    This object is deliberately a simple data holder.  It makes ownership and
    construction explicit while keeping the existing Qt signals and controller
    APIs unchanged.
    """

    paths: AppPaths
    config_store: ConfigStore
    tool_registry: ToolRegistry
    execution_manager: ExecutionManager
    execution_coordinator: ExecutionCoordinator
    android_controller: AndroidController
    app_controller: AppController
    settings_controller: SettingsController
    preset_controller: PresetController
    developer_console_controller: DeveloperConsoleController


def build_components(paths: AppPaths) -> ApplicationComponents:
    """Build the application graph from concrete infrastructure adapters."""

    paths.ensure()
    config_store = ConfigStore(paths)
    config_store.load_config()
    python_environment = PythonEnvironment(paths, config_store)
    tool_repository = JsonToolRepository(paths)
    tool_registry = ToolRegistry(resource_path("tools"), tool_repository)
    execution_manager = ExecutionManager(paths, python_environment)
    execution_coordinator = ExecutionCoordinator(
        execution_manager,
        config_store.max_parallel(),
    )
    android_controller = AndroidController(config_store)
    app_controller = AppController(
        tool_registry,
        execution_coordinator,
        config_store,
        android_controller,
    )
    settings_controller = SettingsController(
        config_store, python_environment, execution_coordinator
    )
    preset_controller = PresetController(paths)
    developer_console_controller = DeveloperConsoleController(python_environment, paths.data_dir)
    settings_controller.scriptsImported.connect(app_controller.reloadImportedScripts)
    settings_controller.consoleMessage.connect(app_controller.appendConsoleMessage)
    return ApplicationComponents(
        paths=paths,
        config_store=config_store,
        tool_registry=tool_registry,
        execution_manager=execution_manager,
        execution_coordinator=execution_coordinator,
        android_controller=android_controller,
        app_controller=app_controller,
        settings_controller=settings_controller,
        preset_controller=preset_controller,
        developer_console_controller=developer_console_controller,
    )
