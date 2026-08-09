from __future__ import annotations

import json
from datetime import UTC, datetime

from PySide6.QtCore import QObject, Slot


class PresetController(QObject):
    """Pure local preset operations shared by the preset workspace."""

    @Slot(str, bool, result=str)
    def formatJson(self, raw: str, compact: bool = False) -> str:
        try:
            value = json.loads(raw)
            if compact:
                return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
            return json.dumps(value, ensure_ascii=False, indent=2)
        except json.JSONDecodeError as exc:
            return f"JSON 错误：第 {exc.lineno} 行，第 {exc.colno} 列\n{exc.msg}"

    @Slot(str, result=str)
    def convertTimestamp(self, raw: str) -> str:
        value = raw.strip()
        if not value:
            return "请输入有效的时间戳或本地时间"
        try:
            timestamp = float(value)
        except ValueError:
            try:
                normalized = value[:-1] + "+00:00" if value.endswith(("Z", "z")) else value
                moment = datetime.fromisoformat(normalized).astimezone()
                timestamp = moment.timestamp()
            except (ValueError, OSError, OverflowError):
                return "请输入有效的时间戳或时间，例如 2026-07-29 14:30:00"
        else:
            if abs(timestamp) > 10_000_000_000:
                timestamp /= 1000
            try:
                moment = datetime.fromtimestamp(timestamp, UTC).astimezone()
            except (ValueError, OSError, OverflowError):
                return "请输入有效的秒或毫秒时间戳"
        seconds = int(timestamp) if timestamp.is_integer() else timestamp
        milliseconds = round(timestamp * 1000)
        local_time = moment.strftime("%Y-%m-%d %H:%M:%S %Z")
        return f"本地时间：{local_time}\n秒：{seconds}\n毫秒：{milliseconds}"
