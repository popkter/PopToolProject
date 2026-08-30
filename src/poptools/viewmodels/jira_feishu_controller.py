from __future__ import annotations

import copy
import queue
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from PySide6.QtCore import Property, QObject, QThread, QTimer, Signal, Slot

from poptools.infrastructure import jira_feishu_core as core
from poptools.infrastructure.jira_feishu_profiles import JiraFeishuProfileStore


@dataclass(frozen=True)
class _PushJob:
    profile: dict[str, Any]
    action: str
    label: str


class _PushWorker(QThread):
    logMessage = Signal(str)
    jobDone = Signal(str, bool)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._queue: queue.Queue[_PushJob | None] = queue.Queue()
        self._running = True

    def enqueue(self, job: _PushJob) -> None:
        self._queue.put(job)

    def stop(self) -> None:
        self._running = False
        self._queue.put(None)

    def run(self) -> None:
        while self._running:
            job = self._queue.get()
            if job is None:
                break
            self._run_job(job)

    def _run_job(self, job: _PushJob) -> None:
        profile = job.profile
        prefix = f"[{profile.get('name', '?')}] "

        def log(message="") -> None:
            self.logMessage.emit(prefix + str(message))

        try:
            if job.action == "test":
                ok = bool(core.run_test(profile, log))
            else:
                result = core.run_push(profile, log, dry_run=job.action == "dry")
                ok = bool(result.get("ok"))
            self.jobDone.emit(job.label, ok)
        except Exception as exc:
            log(f"❌ 任务异常: {type(exc).__name__}: {exc}")
            self.jobDone.emit(job.label, False)


class JiraFeishuController(QObject):
    """QML-facing profile editor, serial worker, and in-app schedule coordinator."""

    profilesChanged = Signal()
    currentProfileChanged = Signal()
    logTextChanged = Signal()
    busyChanged = Signal()
    statusChanged = Signal()
    scheduleRunningChanged = Signal()

    def __init__(self, data_dir: Path, parent=None) -> None:
        super().__init__(parent)
        self._directory = data_dir / "jira_feishu"
        core.set_data_directory(self._directory)
        self._store = JiraFeishuProfileStore(self._directory)
        self._profiles = self._store.load()
        self._current_index = 0
        self._logs: list[str] = []
        self._busy_count = 0
        self._status = "配置仅保存在本机"
        self._last_run: dict[str, datetime] = {}
        self._fired_today: dict[str, set[str]] = {}

        self._worker = _PushWorker(self)
        self._worker.logMessage.connect(self._append_log)
        self._worker.jobDone.connect(self._on_job_done)
        self._worker.start()

        self._schedule_timer = QTimer(self)
        self._schedule_timer.setInterval(30_000)
        self._schedule_timer.timeout.connect(self._tick_schedule)
        self._schedule_timer.start()

    @Property("QStringList", notify=profilesChanged)
    def profileNames(self) -> list[str]:
        return [str(profile.get("name", "未命名")) for profile in self._profiles]

    @Property(int, notify=currentProfileChanged)
    def currentIndex(self) -> int:
        return self._current_index

    @Property("QVariantMap", notify=currentProfileChanged)
    def currentProfile(self) -> dict[str, Any]:
        if not self._profiles:
            return {}
        return copy.deepcopy(self._profiles[self._current_index])

    @Property(str, notify=logTextChanged)
    def logText(self) -> str:
        return "\n".join(self._logs)

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy_count > 0

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(bool, notify=scheduleRunningChanged)
    def scheduleRunning(self) -> bool:
        return any(bool(p.get("schedule", {}).get("enabled")) for p in self._profiles)

    @Slot(int)
    def selectProfile(self, index: int) -> None:
        if 0 <= index < len(self._profiles) and index != self._current_index:
            self._current_index = index
            self.currentProfileChanged.emit()

    @Slot(str, str, "QVariant")
    def updateField(self, section: str, key: str, value: Any) -> None:
        if not self._profiles:
            return
        profile = self._profiles[self._current_index]
        target = profile if section == "root" else profile.setdefault(section, {})
        if isinstance(target, dict):
            target[key] = value
            if section == "root" and key == "name":
                self.profilesChanged.emit()
            if section == "schedule" and key == "enabled":
                self.scheduleRunningChanged.emit()

    @Slot()
    def newProfile(self) -> None:
        profile = self._store.blank_profile("新配置")
        self._profiles.append(profile)
        self._current_index = len(self._profiles) - 1
        self._save("已新建配置")

    @Slot()
    def duplicateProfile(self) -> None:
        if not self._profiles:
            return
        profile = copy.deepcopy(self._profiles[self._current_index])
        profile["id"] = self._store.new_id()
        profile["name"] = f"{profile.get('name', '配置')}_副本"
        profile.setdefault("schedule", {})["enabled"] = False
        self._profiles.append(profile)
        self._current_index = len(self._profiles) - 1
        self._save("已复制配置")

    @Slot()
    def deleteProfile(self) -> None:
        if len(self._profiles) <= 1:
            self._set_status("至少需要保留一个配置")
            return
        deleted = self._profiles.pop(self._current_index)
        self._current_index = min(self._current_index, len(self._profiles) - 1)
        self._save(f"已删除「{deleted.get('name', '配置')}」")

    @Slot()
    def saveProfiles(self) -> None:
        self._save("配置已保存")
        self._append_log("💾 配置已保存")

    @Slot(str)
    def runAction(self, action: str) -> None:
        if action not in {"test", "dry", "push"} or not self._profiles:
            return
        profile = copy.deepcopy(self._profiles[self._current_index])
        validation_error = self._validate(profile, action)
        if validation_error:
            self._set_status(validation_error)
            self._append_log(f"⚠️ {validation_error}")
            return
        self._store.save(self._profiles)
        label = f"{profile.get('name', '?')}-{action}"
        self._enqueue(profile, action, label)
        verb = {"test": "测试连接", "dry": "预览", "push": "推送"}[action]
        self._append_log(f"➡️ 已提交任务：{verb}（{profile.get('name')}）")

    @Slot()
    def startSchedule(self) -> None:
        if not self._profiles:
            return
        self._profiles[self._current_index].setdefault("schedule", {})["enabled"] = True
        self._store.save(self._profiles)
        self.currentProfileChanged.emit()
        self.scheduleRunningChanged.emit()
        self._tick_schedule()
        self._append_log("⏰ 定时调度已启动（对所有已启用配置生效）")

    @Slot()
    def stopSchedule(self) -> None:
        for profile in self._profiles:
            profile.setdefault("schedule", {})["enabled"] = False
        self._store.save(self._profiles)
        self.currentProfileChanged.emit()
        self.scheduleRunningChanged.emit()
        self._append_log("⏹️ 已停止所有定时调度")

    @Slot()
    def clearLog(self) -> None:
        self._logs.clear()
        self.logTextChanged.emit()

    @Slot()
    def shutdown(self) -> None:
        self._store.save(self._profiles)
        self._schedule_timer.stop()
        self._worker.stop()
        self._worker.wait(2_000)

    def _save(self, status: str) -> None:
        self._store.save(self._profiles)
        self.profilesChanged.emit()
        self.currentProfileChanged.emit()
        self.scheduleRunningChanged.emit()
        self._set_status(status)

    def _enqueue(self, profile: dict[str, Any], action: str, label: str) -> None:
        self._busy_count += 1
        self.busyChanged.emit()
        self._worker.enqueue(_PushJob(profile, action, label))

    @staticmethod
    def _validate(profile: dict[str, Any], action: str) -> str:
        jira = profile.get("jira", {})
        feishu = profile.get("feishu", {})
        token = jira.get("token") or jira.get("pat")
        if not jira.get("base_url") or not token:
            return "请先填写 Jira 地址和 Token"
        if action in {"dry", "push"} and not jira.get("jql_filter"):
            return "请先填写 JQL 语句"
        if action == "push" and not feishu.get("webhook_url"):
            return "推送前请填写飞书 Webhook URL"
        return ""

    @Slot(str)
    def _append_log(self, message: str) -> None:
        timestamp = datetime.now().strftime("%H:%M:%S")
        self._logs.append(f"[{timestamp}] {message}")
        self._logs = self._logs[-500:]
        self.logTextChanged.emit()

    @Slot(str, bool)
    def _on_job_done(self, label: str, ok: bool) -> None:
        self._busy_count = max(0, self._busy_count - 1)
        self.busyChanged.emit()
        result = "成功" if ok else "失败"
        self._append_log(f"✔️ 任务完成：{label} — {result}")
        self._set_status(f"{label}：{result}")

    def _set_status(self, status: str) -> None:
        if self._status != status:
            self._status = status
            self.statusChanged.emit()

    @staticmethod
    def _parse_times(value: Any) -> list[str]:
        text = value if isinstance(value, str) else ",".join(value or [])
        result = []
        for part in text.replace("，", ",").split(","):
            candidate = part.strip()
            if re.match(r"^\d{1,2}:\d{2}$", candidate):
                hour, minute = candidate.split(":")
                if 0 <= int(hour) < 24 and 0 <= int(minute) < 60:
                    result.append(f"{int(hour):02d}:{minute}")
        return result or ["09:00"]

    @Slot(str)
    def updateDailyTimes(self, value: str) -> None:
        self.updateField("schedule", "daily_times", self._parse_times(value))
        self.currentProfileChanged.emit()

    @Slot()
    def _tick_schedule(self) -> None:
        now = datetime.now()
        for profile in self._profiles:
            schedule = profile.get("schedule", {})
            if not schedule.get("enabled"):
                continue
            profile_id = str(profile.get("id", ""))
            if schedule.get("mode") == "interval":
                minutes = int(schedule.get("interval_minutes", 60) or 60)
                last = self._last_run.get(profile_id)
                if last is None or now - last >= timedelta(minutes=minutes):
                    self._fire(profile)
                    self._last_run[profile_id] = now
            elif schedule.get("mode") == "daily":
                times = self._parse_times(schedule.get("daily_times", []))
                fired = self._fired_today.setdefault(profile_id, set())
                current = now.strftime("%H:%M")
                for target in times:
                    if target <= current and target not in fired:
                        self._fire(profile)
                        fired.add(target)
                if times and current < min(times):
                    fired.clear()

    def _fire(self, profile: dict[str, Any]) -> None:
        copied = copy.deepcopy(profile)
        error = self._validate(copied, "push")
        if error:
            self._append_log(f"⚠️ [{copied.get('name', '?')}] 定时任务跳过：{error}")
            return
        self._append_log(
            f"⏰ 定时触发：{copied.get('name')}（{datetime.now().strftime('%H:%M:%S')}）"
        )
        self._enqueue(copied, "push", f"{copied.get('name')}-定时")
