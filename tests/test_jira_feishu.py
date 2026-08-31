from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from poptools.infrastructure import jira_feishu_core as core
from poptools.infrastructure.jira_feishu_profiles import JiraFeishuProfileStore
from poptools.viewmodels.jira_feishu_controller import JiraFeishuController


def test_profile_store_migrates_legacy_config(tmp_path):
    legacy = {
        "jira": {
            "base_url": "https://jira.test",
            "pat": "legacy-token",
            "proxy": "http://legacy-proxy.test:7890",
        },
        "feishu": {"webhook_url": "https://feishu.test/hook"},
        "message": {"at_assignee": False},
    }
    (tmp_path / "config.json").write_text(json.dumps(legacy), encoding="utf-8")

    profiles = JiraFeishuProfileStore(tmp_path).load()

    assert len(profiles) == 1
    assert profiles[0]["name"] == "默认"
    assert core.jira_creds(profiles[0]["jira"])[1] == "legacy-token"
    assert "proxy" not in profiles[0]["jira"]
    assert profiles[0]["schedule"]["mode"] == "interval"


def test_new_profile_has_no_default_jira_address(tmp_path):
    profile = JiraFeishuProfileStore(tmp_path).blank_profile()

    assert profile["jira"]["base_url"] == ""


def test_controller_saves_feishu_keyword(qapp, tmp_path):
    controller = JiraFeishuController(tmp_path)
    try:
        controller.updateField("feishu", "keyword", "质量播报")
        controller.saveProfiles()

        saved = JiraFeishuProfileStore(tmp_path / "jira_feishu").load()
        assert saved[0]["feishu"]["keyword"] == "质量播报"
    finally:
        controller.shutdown()


def test_dwell_time_uses_latest_assignment_to_current_owner():
    assigned_at = datetime.now(UTC) - timedelta(days=2, hours=3)
    issue = {
        "fields": {
            "created": "2020-01-01T00:00:00.000+0000",
            "assignee": {"name": "current", "displayName": "Current"},
        },
        "changelog": {
            "histories": [
                {
                    "created": assigned_at.strftime("%Y-%m-%dT%H:%M:%S.000+0000"),
                    "items": [
                        {
                            "field": "assignee",
                            "fromString": "Previous",
                            "toString": "Current",
                        }
                    ],
                }
            ]
        },
    }

    seconds = core._assignee_dwell(issue, datetime.now(UTC))

    assert 2 * 86400 + 2 * 3600 < seconds < 2 * 86400 + 4 * 3600


def test_card_builder_splits_large_issue_sets(monkeypatch):
    monkeypatch.setattr(core, "resolve_open_ids", lambda _config, _emails: {})
    config = {
        "jira": {"base_url": "https://jira.test"},
        "feishu": {"keyword": "质量播报", "secret": ""},
        "message": {"at_assignee": True, "email_domain": "@example.com"},
    }
    issues = []
    for index in range(300):
        issues.append(
            {
                "key": f"APP-{index}",
                "fields": {
                    "summary": f"Issue summary {index}",
                    "status": {"name": "Open"},
                    "priority": {"name": "P1"},
                    "created": "2026-01-01T00:00:00.000+0000",
                    "assignee": {
                        "displayName": "Owner",
                        "emailAddress": "owner@example.com",
                    },
                },
                "changelog": {"histories": []},
            }
        )

    messages = core.build_feishu_messages(config, issues)

    assert len(messages) > 1
    assert all(body["msg_type"] == "interactive" for _label, body in messages)
    first_body = messages[0][1]
    assert "质量播报" in first_body["card"]["header"]["title"]["content"]
