from __future__ import annotations

import re
from typing import Any

from pypinyin import lazy_pinyin
from PySide6.QtCore import (
    Property,
    QObject,
    QRect,
    QTimer,
    Signal,
    Slot,
)
from PySide6.QtGui import QWindow

from poptools.domain.models import (
    ExecutorKind,
    ParameterKind,
    ToolDefinition,
    ToolSection,
)
from poptools.infrastructure.background_process import BackgroundProcess
from poptools.infrastructure.config_store import ConfigStore
from poptools.infrastructure.python_doctor import PythonDoctor, PythonDoctorResult
from poptools.infrastructure.tool_registry import ToolRegistry
from poptools.runners import ExecutionCoordinator
from poptools.viewmodels.android_controller import AndroidController
from poptools.viewmodels.tool_list_model import ToolListModel

SECTION_TITLES = {
    ToolSection.PRESET: "预设功能",
    ToolSection.CUSTOM: "客制功能",
}

CONSOLE_REFRESH_INTERVAL_MS = 50
CONSOLE_MAX_CHARS = 200_000
CONSOLE_RETAINED_CHARS = 150_000


class AppController(QObject):
    sectionChanged = Signal()
    sectionTitleChanged = Signal()
    selectedToolChanged = Signal()
    consoleTextChanged = Signal()
    runningChanged = Signal()
    statusTextChanged = Signal()
    pythonDoctorWarning = Signal(str)
    executionCapacityRequested = Signal(str, str)
    toolSortModeChanged = Signal()

    def __init__(
        self,
        registry: ToolRegistry,
        execution_coordinator: ExecutionCoordinator,
        config_store: ConfigStore,
        android_controller: AndroidController,
        python_doctor: PythonDoctor | None = None,
    ) -> None:
        super().__init__()
        self.registry = registry
        self.execution_coordinator = execution_coordinator
        self.execution = execution_coordinator.execution
        self.config_store = config_store
        self._section = ToolSection.CUSTOM
        self._selected: ToolDefinition | None = None
        self._console_texts = {"": "14:20:15  泡泡工具箱 已就绪\n"}
        self._pending_console_chunks: dict[str, list[str]] = {}
        self._console_refresh_timer = QTimer(self)
        self._console_refresh_timer.setSingleShot(True)
        self._console_refresh_timer.setInterval(CONSOLE_REFRESH_INTERVAL_MS)
        self._console_refresh_timer.timeout.connect(self._flush_console)
        self._status_text = "就绪"
        self._tool_sort_mode = config_store.tool_sort_mode()
        self._tools_model = ToolListModel()
        self.android_controller = android_controller
        self._python_doctor = python_doctor or PythonDoctor()
        self.execution_coordinator.output.connect(self._queue_console)
        self.execution_coordinator.started.connect(self._on_execution_started)
        self.execution_coordinator.runningChanged.connect(self._on_execution_running_changed)
        self.execution_coordinator.finished.connect(self._on_execution_finished)
        self.execution_coordinator.capacityRequested.connect(self.executionCapacityRequested)
        self._refresh(select_first=True)

    @Property(QObject, constant=True)
    def toolsModel(self) -> QObject:
        return self._tools_model

    @Property(str, notify=sectionChanged)
    def section(self) -> str:
        return self._section.value

    @Property(str, notify=sectionTitleChanged)
    def sectionTitle(self) -> str:
        return SECTION_TITLES[self._section]

    @Property("QVariantMap", notify=selectedToolChanged)
    def selectedTool(self) -> dict[str, Any]:
        if self._selected is None:
            return {}
        data = self._selected.to_qml()
        data["parameters"] = [
            parameter
            for parameter in data["parameters"]
            if parameter["kind"] != ParameterKind.ANDROID_DEVICE.value
        ]
        data["uses_android_device"] = self._tool_uses_adb(self._selected)
        data["workspace"] = (
            "scrcpy"
            if self.execution_coordinator.is_scrcpy(self._selected)
            else "preset"
            if self._selected.executor.kind == ExecutorKind.INTERNAL
            else "command"
        )
        return data

    @Property(str, notify=consoleTextChanged)
    def consoleText(self) -> str:
        return self._console_texts.get("", "")

    @Property(bool, notify=runningChanged)
    def running(self) -> bool:
        if self._selected is None:
            return False
        return self.execution_coordinator.running(self._selected.id)

    @Property(str, notify=statusTextChanged)
    def statusText(self) -> str:
        return self._status_text

    @Property(str, notify=toolSortModeChanged)
    def toolSortMode(self) -> str:
        return self._tool_sort_mode

    @Property(str, notify=toolSortModeChanged)
    def toolSortModeLabel(self) -> str:
        return {
            "added_time": "按添加时间",
            "name": "按名称",
            "usage": "按使用频率",
            "custom": "自定义排序",
        }[self._tool_sort_mode]

    @Slot(str)
    def navigate(self, section: str) -> None:
        target = ToolSection(section)
        if target == self._section:
            return
        self._section = target
        self.sectionChanged.emit()
        self.sectionTitleChanged.emit()
        self._refresh(select_first=True)

    @Slot(str)
    def selectTool(self, tool_id: str) -> None:
        tool = self.registry.get(tool_id)
        if tool is None:
            return
        previous_id = self._selected.id if self._selected is not None else ""
        previous = self.registry.get(previous_id) if previous_id else None
        if (
            previous is not None
            and self.execution_coordinator.is_scrcpy(previous)
            and not self.execution_coordinator.is_scrcpy(tool)
        ):
            self._hide_scrcpy_window()
        self._selected = tool
        self._tools_model.select(tool_id)
        self.selectedToolChanged.emit()
        self.consoleTextChanged.emit()
        self.runningChanged.emit()
        self._status_text = "运行中" if self.running else "就绪"
        self.statusTextChanged.emit()

    @Slot(str, result=bool)
    def setToolSortMode(self, mode: str) -> bool:
        try:
            self.config_store.set_tool_sort_mode(mode)
        except (OSError, ValueError):
            return False
        if mode == self._tool_sort_mode:
            return True
        self._tool_sort_mode = mode
        self.toolSortModeChanged.emit()
        selected_id = self._selected.id if self._selected is not None else ""
        self._refresh(select_id=selected_id)
        return True

    @Slot(str, int, result=bool)
    def moveTool(self, tool_id: str, target_index: int) -> bool:
        if self._section != ToolSection.CUSTOM or self._tool_sort_mode != "custom":
            return False
        tools = self._sorted_tools(self.registry.for_section(self._section))
        source_index = next((i for i, tool in enumerate(tools) if tool.id == tool_id), -1)
        if source_index < 0 or not tools:
            return False
        target_index = max(0, min(target_index, len(tools) - 1))
        moved = tools.pop(source_index)
        tools.insert(target_index, moved)
        try:
            self.config_store.set_tool_order([tool.id for tool in tools])
        except OSError:
            return False
        self._refresh(select_id=tool_id)
        return True

    def attach_window(self, window: QWindow) -> None:
        self.execution_coordinator.attach_window(window)

    @Slot("QVariantMap", result=bool)
    def runSelected(self, values: dict[str, Any]) -> bool:
        if self._selected is None:
            return False
        selected_device = self.android_controller.selectedAndroidDevice
        if self._tool_requires_android_device(self._selected) and not selected_device:
            self._append_console("未检测到已连接的 Android 设备，请连接设备并刷新。\n")
            self._status_text = "等待 Android 设备"
            self.statusTextChanged.emit()
            return False

        run_values = dict(values)
        if selected_device and self._tool_uses_adb(self._selected):
            run_values["device"] = selected_device
            run_values["__android_device__"] = selected_device
        self._status_text = "正在启动"
        self.statusTextChanged.emit()
        started = self.execution_coordinator.start(
            self._selected,
            run_values,
            selected_device,
        )
        if not started:
            self._status_text = "就绪"
            self.statusTextChanged.emit()
        return started

    @Slot()
    def stopExecution(self) -> None:
        if self._selected is None:
            return
        self.execution_coordinator.stop(self._selected.id)

    @Slot(int, int, int, int, bool)
    def updateScrcpyGeometry(self, x: int, y: int, width: int, height: int, visible: bool) -> None:
        self.execution_coordinator.set_scrcpy_geometry(QRect(x, y, width, height), visible)

    def _hide_scrcpy_window(self) -> None:
        self.execution_coordinator.set_scrcpy_geometry(QRect(), False)

    @Slot()
    def clearConsole(self) -> None:
        self._pending_console_chunks.pop("", None)
        if not self._pending_console_chunks:
            self._console_refresh_timer.stop()
        self._console_texts[""] = ""
        self.consoleTextChanged.emit()

    @Slot(str)
    def appendConsoleMessage(self, text: str) -> None:
        self._append_console(text)

    @Slot()
    def reloadImportedScripts(self) -> None:
        selected_id = self._selected.id if self._selected is not None else ""
        self.registry.reload()
        self._refresh(select_id=selected_id, select_first=not bool(selected_id))
        if self._selected is None:
            self._refresh(select_first=True)

    @Slot(str, str, str, str, result=bool)
    @Slot(str, str, str, str, str, result=bool)
    def saveSelected(
        self, title: str, description: str, kind: str, command: str, icon: str = ""
    ) -> bool:
        if (
            self._selected is None
            or (self._selected.section != ToolSection.CUSTOM and not self._selected.editable)
            or self.running
        ):
            return False
        try:
            self.registry.update_tool(
                self._selected.id,
                title=title,
                description=description,
                kind=ExecutorKind(kind),
                command=command,
                args=[],
                icon=icon or None,
            )
            selected_id = self._selected.id
            self._refresh(select_id=selected_id)
            self._append_console("工具修改已保存到本地配置。\n")
            return True
        except Exception as exc:
            self._append_console(f"保存失败：{exc}\n")
            return False

    @Slot(str, str, str, str, result=bool)
    @Slot(str, str, str, str, str, result=bool)
    def createCommand(
        self,
        title: str,
        description: str,
        kind: str,
        command: str,
        icon: str = "terminal",
    ) -> bool:
        try:
            tool = self.registry.create_custom(
                title=title,
                description=description,
                kind=ExecutorKind(kind),
                command=command,
                icon=icon,
            )
            if self._section != ToolSection.CUSTOM:
                self._section = ToolSection.CUSTOM
                self.sectionChanged.emit()
                self.sectionTitleChanged.emit()
            self._refresh(select_id=tool.id)
            self._append_console("自定义命令已保存到客制功能。\n")
            if tool.executor.kind == ExecutorKind.PYTHON:
                self._run_python_doctor(command)
            return True
        except Exception as exc:
            self._append_console(f"新建失败：{exc}\n")
            return False

    def _run_python_doctor(self, command: str) -> None:
        plan = self._python_doctor.prepare(command)
        if plan.immediate_result is not None:
            self._report_python_doctor_result(plan.immediate_result)
            return
        executable = self.execution.python_environment.executable()
        if not executable:
            self._report_python_doctor_result(
                PythonDoctorResult(
                    checked_modules=plan.checked_modules,
                    environment_error="Python 解释器不可用",
                )
            )
            return
        if not plan.modules_to_check:
            self._report_python_doctor_result(
                PythonDoctorResult(checked_modules=plan.checked_modules),
                executable,
            )
            return

        process = BackgroundProcess(self)
        stdout = bytearray()
        stderr = bytearray()
        errors: list[str] = []
        timed_out = [False]
        timeout = QTimer(process)
        timeout.setSingleShot(True)

        def stop_on_timeout() -> None:
            timed_out[0] = True
            process.kill()

        def finish(exit_code: int) -> None:
            timeout.stop()
            if timed_out[0]:
                result = PythonDoctorResult(
                    checked_modules=plan.checked_modules,
                    environment_error="依赖检查超时",
                )
            else:
                error_text = stderr.decode("utf-8", "replace")
                if errors:
                    error_text = "\n".join([error_text, *errors]).strip()
                result = self._python_doctor.complete_probe(
                    plan,
                    exit_code,
                    stdout.decode("utf-8", "replace"),
                    error_text,
                )
            self._report_python_doctor_result(result, executable)
            process.deleteLater()

        process.stdoutReady.connect(stdout.extend)
        process.stderrReady.connect(stderr.extend)
        process.errorOccurred.connect(errors.append)
        process.finished.connect(finish)
        timeout.timeout.connect(stop_on_timeout)
        self._append_console("Python Doctor：正在异步检查依赖…\n")
        process.start(
            executable,
            ["-c", self._python_doctor.probe_source(), *plan.modules_to_check],
        )
        timeout.start(20_000)

    def _report_python_doctor_result(
        self,
        result: PythonDoctorResult,
        executable: str | None = None,
    ) -> None:
        executable = executable or self.execution.python_environment.executable()
        if result.environment_error:
            message = f"Python Doctor 无法检查所选环境：{result.environment_error}"
            self._append_console(f"{message}\n")
            self.pythonDoctorWarning.emit(
                f"脚本已创建，但 Python 环境不可用。\n\n{result.environment_error}\n\n"
                "请在设置中配置 Python 解释器。"
            )
        elif result.missing_modules:
            modules = "、".join(result.missing_modules)
            package_names = " ".join(result.missing_modules)
            install_command = f'"{executable}" -m pip install {package_names}'
            message = f"Python Doctor 发现缺失依赖：{modules}"
            self._append_console(f"{message}\n")
            self.pythonDoctorWarning.emit(
                f"脚本已创建，但当前 Python 环境缺少以下模块：\n\n{modules}\n\n"
                f"可使用以下命令安装后再运行：\n\n{install_command}"
            )
        elif result.syntax_error:
            message = f"Python Doctor 无法完成检查，脚本存在语法错误：{result.syntax_error}"
            self._append_console(f"{message}\n")
            self.pythonDoctorWarning.emit(
                f"脚本已创建，但 Python Doctor 无法完成依赖检查。\n\n{result.syntax_error}"
            )
        else:
            self._append_console("Python Doctor：未发现缺失依赖。\n")

    @Slot(result=bool)
    def deleteSelected(self) -> bool:
        if self._selected is None or self._selected.section != ToolSection.CUSTOM or self.running:
            return False
        title = self._selected.title
        if not self.registry.delete(self._selected.id):
            return False
        self._selected = None
        self._refresh(select_first=True)
        self._append_console(f"已删除本地命令：{title}\n")
        return True

    def _refresh(self, *, select_first: bool = False, select_id: str = "") -> None:
        tools = self._sorted_tools(self.registry.for_section(self._section))
        target_id = select_id
        if not target_id and self._selected and self._selected.section == self._section:
            target_id = self._selected.id
        if select_first and tools:
            target_id = tools[0].id
        self._selected = self.registry.get(target_id) if target_id else None
        self._tools_model.set_tools(tools, target_id)
        self.selectedToolChanged.emit()
        self.consoleTextChanged.emit()
        self.runningChanged.emit()
        self._status_text = "运行中" if self.running else "就绪"
        self.statusTextChanged.emit()

    def _sorted_tools(self, tools: list[ToolDefinition]) -> list[ToolDefinition]:
        if self._section != ToolSection.CUSTOM:
            return tools
        tool_ids = [tool.id for tool in tools]
        added_times = self.config_store.tool_added_times(tool_ids)
        if self._tool_sort_mode == "added_time":
            return sorted(tools, key=lambda tool: (-added_times[tool.id], tool.title.casefold()))
        if self._tool_sort_mode == "name":
            return sorted(tools, key=lambda tool: (self._name_sort_key(tool.title), tool.id))
        if self._tool_sort_mode == "usage":
            counts = self.config_store.tool_usage_counts()
            return sorted(
                tools,
                key=lambda tool: (-counts.get(tool.id, 0), tool.title.casefold(), tool.id),
            )
        order = {tool_id: index for index, tool_id in enumerate(self.config_store.tool_order())}
        return sorted(
            tools,
            key=lambda tool: (
                order.get(tool.id, len(order) + tool.presentation.order),
                tool.title.casefold(),
            ),
        )

    @staticmethod
    def _name_sort_key(title: str) -> str:
        """Compare Chinese and Latin names through one case-insensitive pinyin key."""
        return "".join(lazy_pinyin(title)).casefold()

    @staticmethod
    def _tool_uses_adb(tool: ToolDefinition) -> bool:
        requirements = {item.lower() for item in tool.executor.requirements}
        command = tool.executor.command.strip().lower()
        return "adb" in requirements or bool(
            re.search(r"(?im)(?:^|[;&|])\s*(?:&\s*)?adb(?:\.exe)?(?=\s|$)", command)
        )

    @staticmethod
    def _tool_requires_android_device(tool: ToolDefinition) -> bool:
        requirements = {item.lower() for item in tool.executor.requirements}
        return "android_device" in requirements or any(
            parameter.kind == ParameterKind.ANDROID_DEVICE for parameter in tool.parameters
        )

    @Slot()
    def confirmExecutionReplacement(self) -> None:
        self.execution_coordinator.confirm_replacement()

    @Slot()
    def cancelExecutionReplacement(self) -> None:
        self.execution_coordinator.cancel_replacement()

    def _on_execution_started(self, tool_id: str) -> None:
        tool = self.registry.get(tool_id)
        if tool is not None:
            self._record_tool_usage(tool)
        if self._selected is not None and self._selected.id == tool_id:
            self._status_text = "运行中"
            self.statusTextChanged.emit()

    def _record_tool_usage(self, tool: ToolDefinition) -> None:
        if tool.section != ToolSection.CUSTOM:
            return
        self.config_store.increment_tool_usage(tool.id)
        if self._tool_sort_mode == "usage":
            self._refresh(select_id=tool.id)

    def _on_execution_running_changed(self, tool_id: str, running: bool) -> None:
        if self._selected is None or self._selected.id != tool_id:
            return
        self.runningChanged.emit()
        self._status_text = "运行中" if running else "就绪"
        self.statusTextChanged.emit()

    def _on_execution_finished(self, tool_id: str, exit_code: int) -> None:
        self._flush_console()
        if self._selected is None or self._selected.id != tool_id:
            return
        self.runningChanged.emit()
        self._status_text = "执行成功" if exit_code == 0 else f"执行失败 ({exit_code})"
        self.statusTextChanged.emit()



    def _append_console(self, text: str) -> None:
        self._commit_console("", text)

    def _queue_console(self, _tool_id: str, text: str) -> None:
        """Coalesce high-volume process output before notifying the QML text view."""
        if not text:
            return
        key = ""
        self._pending_console_chunks.setdefault(key, []).append(text)
        if not self._console_refresh_timer.isActive():
            self._console_refresh_timer.start()

    def _flush_console(self) -> None:
        if not self._pending_console_chunks:
            return
        pending = self._pending_console_chunks
        self._pending_console_chunks = {}
        for key, chunks in pending.items():
            self._store_console(key, "".join(chunks))
        self.consoleTextChanged.emit()

    def _commit_console(self, key: str, text: str) -> None:
        self._store_console(key, text)
        self.consoleTextChanged.emit()

    def _store_console(self, key: str, text: str) -> None:
        value = self._console_texts.get(key, "")
        value += text
        if len(value) > CONSOLE_MAX_CHARS:
            value = value[-CONSOLE_RETAINED_CHARS:]
        self._console_texts[key] = value
