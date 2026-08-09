from __future__ import annotations

import copy
import hashlib
import json
import uuid
from pathlib import Path
from typing import Any

DEFAULT_SCHEDULE = {
    "enabled": False,
    "mode": "interval",
    "interval_minutes": 60,
    "daily_times": ["09:00", "15:00", "18:00"],
}

_LEGACY_EMAIL_DOMAIN_HASH = "781b6c84a66b400a768d11b3a68d5a9e3a661101ab7de6e1ad722e2051bb0229"


def _is_legacy_email_domain(value: object) -> bool:
    if not isinstance(value, str):
        return False
    normalized = value.strip().casefold().encode("utf-8")
    return hashlib.sha256(normalized).hexdigest() == _LEGACY_EMAIL_DOMAIN_HASH


class JiraFeishuProfileStore:
    """Persist Jira/Feishu profiles under the PopTools user-data directory."""

    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.profiles_path = directory / "profiles.json"
        self.legacy_config_path = directory / "config.json"

    @staticmethod
    def new_id() -> str:
        return uuid.uuid4().hex[:8]

    def blank_profile(self, name: str = "新配置") -> dict[str, Any]:
        return {
            "id": self.new_id(),
            "name": name,
            "jira": {
                "base_url": "",
                "token": "",
                "jql_filter": "status != Done ORDER BY assignee ASC, priority DESC",
                "max_results": 200,
            },
            "feishu": {
                "webhook_url": "",
                "keyword": "",
                "secret": "",
                "app_id": "",
                "app_secret": "",
            },
            "message": {
                "language": "zh_cn",
                "at_assignee": True,
                "email_domain": "",
            },
            "schedule": copy.deepcopy(DEFAULT_SCHEDULE),
        }

    def normalize(self, profile: dict[str, Any]) -> dict[str, Any]:
        profile = copy.deepcopy(profile)
        profile.setdefault("id", self.new_id())
        profile.setdefault("name", "未命名")
        for section in ("jira", "feishu", "message"):
            profile.setdefault(section, {})
        message = profile["message"]
        if not isinstance(message, dict):
            message = {}
            profile["message"] = message
        if _is_legacy_email_domain(message.get("email_domain")):
            message["email_domain"] = ""
        message.setdefault("email_domain", "")
        jira = profile["jira"]
        jira.pop("proxy", None)
        if "token" not in jira and "pat" in jira:
            jira["token"] = jira.pop("pat")
        jira.setdefault("token", "")
        schedule = profile.get("schedule")
        merged = copy.deepcopy(DEFAULT_SCHEDULE)
        if isinstance(schedule, dict):
            merged.update(schedule)
        profile["schedule"] = merged
        return profile

    def _migrate_from_config(self) -> dict[str, Any]:
        profile = self.blank_profile("默认")
        try:
            config = json.loads(self.legacy_config_path.read_text(encoding="utf-8"))
            for section in ("jira", "feishu", "message"):
                if isinstance(config.get(section), dict):
                    profile[section].update(config[section])
        except (OSError, json.JSONDecodeError, AttributeError):
            pass
        return profile

    def load(self) -> list[dict[str, Any]]:
        self.directory.mkdir(parents=True, exist_ok=True)
        if not self.profiles_path.exists():
            profiles = [self.normalize(self._migrate_from_config())]
            self.save(profiles)
            return profiles
        try:
            data = json.loads(self.profiles_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            data = []
        raw_profiles = (
            [item for item in data if isinstance(item, dict)]
            if isinstance(data, list)
            else []
        )
        profiles = [self.normalize(item) for item in raw_profiles]
        if any(
            isinstance(item.get("message"), dict)
            and _is_legacy_email_domain(item["message"].get("email_domain"))
            for item in raw_profiles
        ):
            self.save(profiles)
        if not profiles:
            profiles = [self.blank_profile("默认")]
            self.save(profiles)
        return profiles

    def save(self, profiles: list[dict[str, Any]]) -> None:
        self.directory.mkdir(parents=True, exist_ok=True)
        normalized = [self.normalize(profile) for profile in profiles]
        temp_path = self.profiles_path.with_suffix(".json.tmp")
        temp_path.write_text(
            json.dumps(normalized, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        temp_path.replace(self.profiles_path)
