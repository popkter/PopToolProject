#!/usr/bin/env python3
"""
Jira 看板 → 飞书群定时推送机器人

功能：
  1. 从 Jira 拉取看板上的 Issue（支持 Board API 和 JQL 搜索两种模式）
  2. 按负责人（assignee）分组
  3. 构建飞书富文本消息（post 格式）
  4. 通过自定义机器人 webhook 发送到飞书群
  5. @ 对应负责人（使用邮箱前缀作为飞书 User ID）

用法：
  python jira_to_feishu.py              # 正常推送
  python jira_to_feishu.py --dry-run    # 只打印消息内容，不发送到飞书
  python jira_to_feishu.py --test-jira  # 只测试 Jira 连通性
"""

import base64
import hashlib
import hmac
import json
import ssl
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import requests
import urllib3
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context

# Windows 控制台默认 GBK 编码，打印 emoji 会抛 UnicodeEncodeError，强制 UTF-8 输出
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

# 禁用 SSL 不安全请求的警告
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ─── 日志 sink ──────────────────────────────────────────────
# 模块级日志出口，GUI 可通过 set_log() 接管，把输出重定向到日志面板。
# 单 worker 线程串行执行所有推送，任意时刻只有一个推送在跑，故全局 sink 无并发竞争。
def _default_log(msg=""):
    print(msg)


_LOG = _default_log


def set_log(fn):
    """设置模块级日志出口；传 None 或不调则回退到 print。"""
    global _LOG
    _LOG = fn or _default_log

# 自定义 SSL 适配器，兼容企业内网老版本 TLS
class LegacySSLAdapter(HTTPAdapter):
    """支持 TLS 1.0/1.1/1.2 的自定义适配器，解决企业内网 SSL 握手问题"""

    def init_poolmanager(self, *args, **kwargs):
        ctx = create_urllib3_context()
        # 允许所有 TLS 版本，兼容老服务器
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        # 设置协议范围
        ctx.options |= 0x4  # OP_LEGACY_SERVER_CONNECT
        kwargs["ssl_context"] = ctx
        return super().init_poolmanager(*args, **kwargs)

# ─── 配置加载 ───────────────────────────────────────────────

CONFIG_PATH = Path(__file__).parent / "config.json"


def set_data_directory(directory):
    """Point mutable Jira/Feishu data files at the application's user-data directory."""
    global CONFIG_PATH, MAPPING_PATH, CACHE_PATH
    data_dir = Path(directory)
    data_dir.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH = data_dir / "config.json"
    MAPPING_PATH = data_dir / "user_mapping.json"
    CACHE_PATH = data_dir / "open_id_cache.json"


def load_config():
    """读取配置文件"""
    if not CONFIG_PATH.exists():
        print(f"❌ 配置文件不存在: {CONFIG_PATH}")
        print("   请先创建 config.json，参考 README.md")
        sys.exit(1)
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


# ─── 飞书签名计算（如果开启了签名校验）──────────────────────

def gen_feishu_sign(timestamp, secret):
    """计算飞书签名（HmacSHA256 + Base64）"""
    string_to_sign = f"{timestamp}\n{secret}"
    hmac_code = hmac.new(
        string_to_sign.encode("utf-8"),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(hmac_code).decode("utf-8")


# ─── Jira API ──────────────────────────────────────────────

def jira_creds(jira_cfg):
    """从 jira 配置段取出 (base_url, token)。

    兼容旧配置的 `pat` 键：若没有 `token` 则回退到 `pat`。
    """
    base_url = jira_cfg.get("base_url", "")
    token = jira_cfg.get("token") or jira_cfg.get("pat", "")
    return base_url, token


class JiraClient:
    """Jira Server (Data Center) REST API 客户端"""

    def __init__(self, base_url, token):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()

        # 挂载自定义 SSL 适配器，跳过证书验证，兼容内网老 TLS
        self.session.mount("https://", LegacySSLAdapter())
        self.session.verify = False  # 跳过 SSL 证书验证（内网自签名证书）

        # 认证：Token 走 Bearer
        self.session.headers.update({
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        })

    # 只请求需要的字段，大幅减少响应时间和数据量
    # created 用于停留时间兜底；changelog 通过 expand 拉取，用于算分派时长
    ISSUE_FIELDS = "summary,status,priority,assignee,issuetype,created"

    def _fetch_with_retry(self, url, params, max_retries=3):
        """带重试的 GET 请求"""
        for attempt in range(max_retries):
            try:
                resp = self.session.get(url, params=params, timeout=120)
                if resp.status_code == 200:
                    return resp
                _LOG(f"❌ Jira API 错误 (第{attempt+1}次): {resp.status_code}")
                _LOG(f"   响应: {resp.text[:500]}")
                if attempt < max_retries - 1:
                    wait = 5 * (attempt + 1)
                    _LOG(f"   {wait}秒后重试...")
                    time.sleep(wait)
                    continue
                resp.raise_for_status()
            except requests.exceptions.Timeout:
                _LOG(f"⏱️ 请求超时 (第{attempt+1}次)")
                if attempt < max_retries - 1:
                    wait = 5 * (attempt + 1)
                    _LOG(f"   {wait}秒后重试...")
                    time.sleep(wait)
                    continue
                raise
        return resp

    def search_issues(self, jql, max_results=200):
        """通过 JQL 搜索 Issue（expand changelog 以便算停留时间）"""
        url = f"{self.base_url}/rest/api/2/search"
        params = {
            "jql": jql,
            "maxResults": min(max_results, 100),
            "fields": self.ISSUE_FIELDS,
            "expand": "changelog",
        }
        all_issues = []
        start_at = 0
        while True:
            params["startAt"] = start_at
            resp = self._fetch_with_retry(url, params)
            data = resp.json()
            issues = data.get("issues", [])
            total = data.get("total", 0)
            all_issues.extend(issues)
            start_at += len(issues)
            if start_at >= total or not issues:
                break
            if len(all_issues) >= max_results:
                break
            _LOG(f"   已获取 {len(all_issues)}/{total} 个 Issue...")
        return all_issues

    def test_connection(self):
        """测试 Jira 连通性"""
        url = f"{self.base_url}/rest/api/2/myself"
        try:
            _LOG(f"   正在连接: {url}")
            _LOG("   SSL 验证: 已跳过 (verify=False)")
            resp = self.session.get(url, timeout=30)
            _LOG(f"   HTTP 状态码: {resp.status_code}")
            if resp.status_code == 200:
                data = resp.json()
                _LOG("✅ Jira 连接成功！")
                _LOG(f"   当前用户: {data.get('displayName', '?')}")
                _LOG(f"   邮箱: {data.get('emailAddress', '?')}")
                _LOG(f"   账号: {data.get('name', '?')}")
                return True
            elif resp.status_code == 401:
                _LOG("❌ 认证失败 (401): PAT 可能无效或已过期")
                _LOG(f"   响应: {resp.text[:300]}")
                return False
            elif resp.status_code == 403:
                _LOG("❌ 权限不足 (403): PAT 权限可能不够")
                _LOG(f"   响应: {resp.text[:300]}")
                return False
            else:
                _LOG(f"❌ Jira 返回非预期状态码: {resp.status_code}")
                _LOG(f"   响应: {resp.text[:300]}")
                return False
        except requests.exceptions.SSLError as e:
            _LOG(f"❌ SSL 错误: {e}")
            _LOG("   尝试使用 curl 测试: curl -k -H 'Authorization: Bearer <PAT>' <URL>")
            return False
        except requests.exceptions.ConnectionError as e:
            _LOG(f"❌ 连接失败: {e}")
            _LOG("   可能原因: 1)不在公司内网/VPN  2)DNS 无法解析  3)防火墙拦截")
            return False
        except Exception as e:
            _LOG(f"❌ Jira 连接异常: {type(e).__name__}: {e}")
            return False


# ─── 飞书自建应用（解析 open_id）────────────────────────────

class FeishuAppClient:
    """飞书自建应用开放 API 客户端，用于把邮箱解析为 open_id。

    仅在 config.feishu.app_id / app_secret 均配置时启用；
    任何失败只打印警告、返回空结果，不阻断主推送流程。
    """

    BASE = "https://open.feishu.cn"
    # batch_get_id 单次最多 50 个邮箱
    BATCH_SIZE = 50

    def __init__(self, app_id, app_secret):
        self.app_id = app_id
        self.app_secret = app_secret
        self.session = requests.Session()
        self._token = None
        self._token_expire = 0  # epoch 秒

    def get_tenant_access_token(self):
        """获取 tenant_access_token（2h 有效），内存缓存并在到期前 10 分钟刷新"""
        now = time.time()
        if self._token and now < self._token_expire - 600:
            return self._token
        url = f"{self.BASE}/open-apis/auth/v3/tenant_access_token/internal"
        try:
            resp = self.session.post(
                url,
                json={"app_id": self.app_id, "app_secret": self.app_secret},
                timeout=30,
            )
            data = resp.json()
            if data.get("code") != 0:
                _LOG(
                    "⚠️ 获取飞书 tenant_access_token 失败: "
                    f"code={data.get('code')}, msg={data.get('msg')}"
                )
                return None
            self._token = data["tenant_access_token"]
            # expire 单位秒，留 10 分钟余量
            self._token_expire = now + data.get("expire", 7200)
            return self._token
        except Exception as e:
            _LOG(f"⚠️ 获取飞书 tenant_access_token 异常: {type(e).__name__}: {e}")
            return None

    def resolve_emails_to_open_ids(self, emails):
        """批量把邮箱解析为 open_id，返回 {email: open_id 或 None}"""
        result = {}
        if not emails:
            return result
        token = self.get_tenant_access_token()
        if not token:
            return {e: None for e in emails}

        url = f"{self.BASE}/open-apis/contact/v3/users/batch_get_id"
        headers = {"Authorization": f"Bearer {token}"}

        for i in range(0, len(emails), self.BATCH_SIZE):
            chunk = emails[i:i + self.BATCH_SIZE]
            params = [("user_id_type", "open_id")] + [("emails", e) for e in chunk]
            try:
                resp = self.session.get(url, params=params, headers=headers, timeout=30)
                data = resp.json()
                if data.get("code") != 0:
                    _LOG(
                        "⚠️ 飞书 batch_get_id 失败: "
                        f"code={data.get('code')}, msg={data.get('msg')}"
                    )
                    result.update({e: None for e in chunk})
                    continue
                # data.data.user_list: [{user_id, email, mobile}, ...]，未找到时 user_id 为空
                user_list = (data.get("data") or {}).get("user_list", [])
                # 按邮箱建索引
                idx = {}
                for u in user_list:
                    em = u.get("email")
                    uid = u.get("user_id")
                    if em:
                        idx[em] = uid or None
                for e in chunk:
                    result[e] = idx.get(e)
            except Exception as e:
                _LOG(f"⚠️ 飞书 batch_get_id 异常: {type(e).__name__}: {e}")
                result.update({e: None for e in chunk})

        return result


# ─── 飞书消息构建 ──────────────────────────────────────────

MAPPING_PATH = Path(__file__).parent / "user_mapping.json"
CACHE_PATH = Path(__file__).parent / "open_id_cache.json"


def load_user_mapping():
    """加载 user_mapping.json 中的手动覆盖映射（值仍为 ou_请替换 占位符的跳过）"""
    if not MAPPING_PATH.exists():
        return {}
    try:
        with open(MAPPING_PATH, encoding="utf-8") as f:
            data = json.load(f)
        mappings = data.get("mappings", {})
        return {k: v for k, v in mappings.items() if not v.startswith("ou_请替换")}
    except Exception:
        return {}


def _load_open_id_cache():
    """读取本地 open_id 缓存"""
    if not CACHE_PATH.exists():
        return {}
    try:
        with open(CACHE_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _save_open_id_cache(cache):
    """写回本地 open_id 缓存"""
    try:
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except Exception as e:
        _LOG(f"⚠️ 写入 open_id 缓存失败: {e}")


def resolve_open_ids(config, emails):
    """统一入口：把一批 Jira 邮箱解析为飞书用户标识，返回 {email: 用户标识}。

    优先级（高 → 低）：
      1. user_mapping.json 手动覆盖（逃生阀，可填 open_id 或用户名）
      2. open_id_cache.json 本地缓存
      3. 飞书自建应用 batch_get_id 实时解析 open_id（结果回写缓存）
      4. 兜底：邮箱去域名作为飞书用户名（@geely.com 前缀即飞书账号）
    第 4 步保证没有 app_id/app_secret 也能 @；若飞书 webhook 的 at 只认 open_id，
    该兜底值会让 @ 退化为普通文字（消息仍能发出），需真正 @ 时走第 3 步。
    """
    emails = list(dict.fromkeys(e for e in emails if e))  # 去重、去空
    if not emails:
        return {}

    open_id_map = {}

    # 1. 手动覆盖
    manual = load_user_mapping()
    resolved_by_manual = []
    for e in emails:
        if e in manual and manual[e]:
            open_id_map[e] = manual[e]
            resolved_by_manual.append(e)

    # 2. 本地缓存
    cache = _load_open_id_cache()
    for e in emails:
        if e not in open_id_map and cache.get(e):
            open_id_map[e] = cache[e]

    # 3. 实时解析剩下的
    missing = [e for e in emails if e not in open_id_map]
    if missing:
        feishu_cfg = config.get("feishu", {})
        app_id = feishu_cfg.get("app_id", "")
        app_secret = feishu_cfg.get("app_secret", "")
        if app_id and app_secret:
            _LOG(f"🔗 调飞书开放 API 解析 {len(missing)} 个未缓存邮箱...")
            client = FeishuAppClient(app_id, app_secret)
            resolved = client.resolve_emails_to_open_ids(missing)
            for e, uid in resolved.items():
                if uid:
                    open_id_map[e] = uid
                    cache[e] = uid  # 回写缓存
                else:
                    cache[e] = ""  # 标记已查但未找到，避免反复请求
            _save_open_id_cache(cache)
        else:
            _LOG(
                "ℹ️ 未配置飞书 app_id/app_secret，跳过 open_id 自动解析，"
                "改用邮箱前缀作为飞书用户名"
            )

    # 4. 兜底：邮箱去域名 = 飞书用户名（@geely.com 前缀即飞书账号）
    email_domain = config.get("message", {}).get("email_domain", "@geely.com")
    fallback_count = 0
    for e in emails:
        if not open_id_map.get(e):
            if email_domain and e.lower().endswith(email_domain.lower()):
                open_id_map[e] = e[:-len(email_domain)]
                fallback_count += 1
            elif "@" in e:
                open_id_map[e] = e.split("@", 1)[0]
                fallback_count += 1
    if fallback_count:
        _LOG(f"ℹ️ {fallback_count} 个负责人用邮箱前缀作为飞书用户名（兜底映射）")

    # 汇报仍未解析成功的（理论上 geely 邮箱都能兜底，这里基本不会命中）
    unresolved = [e for e in emails if not open_id_map.get(e)]
    if unresolved:
        _LOG(f"⚠️ 以下 {len(unresolved)} 个邮箱未能解析出飞书用户标识，对应负责人不会被 @：")
        for e in unresolved:
            _LOG(f"   {e}")

    return open_id_map


def _parse_jira_dt(s):
    """解析 Jira 时间字符串为 tz-aware datetime，失败返回 None。"""
    if not s:
        return None
    try:
        # 如 2024-01-15T08:30:45.000+0800
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S.%f%z")
    except ValueError:
        pass
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


def _fmt_dwell(seconds):
    """把秒数格式化为停留时长，如 3天5时 / 2时15分 / 45分。"""
    if seconds is None or seconds < 0:
        return ""
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}天{hours}时"
    if hours > 0:
        return f"{hours}时{minutes}分"
    return f"{minutes}分"


def _assignee_dwell(issue, now):
    """计算 issue 在当前负责人名下停留的秒数。

    从 changelog 找最后一次 assignee 变更到当前负责人的时刻；
    找不到（如创建即指派且从未改派）则回退到 issue 的 created。
    返回秒数（int/float）或 None。
    """
    fields = issue.get("fields", {}) or {}
    assignee = fields.get("assignee")
    if not assignee:
        return None
    target_name = assignee.get("name")
    target_display = assignee.get("displayName")

    changelog = issue.get("changelog") or {}
    entries = changelog.get("histories") or changelog.get("items") or []
    latest_ts = None
    for hist in entries:
        ts = hist.get("created")
        items = hist.get("items", [])
        for it in items:
            if it.get("field") != "assignee":
                continue
            to_val = it.get("to")
            to_str = it.get("toString")
            matched = ((to_val and target_name and to_val == target_name)
                       or (to_str and target_display and to_str == target_display))
            if matched and ts:
                latest_ts = ts  # entries 按时间正序，后出现的更新
    if latest_ts:
        dt = _parse_jira_dt(latest_ts)
        if dt:
            return (now - dt).total_seconds()
    # 回退到创建时间
    created = fields.get("created")
    if created:
        dt = _parse_jira_dt(created)
        if dt:
            return (now - dt).total_seconds()
    return None


def group_issues_by_assignee(config, issues):
    """将 Issue 列表按负责人分组，返回 (groups, unassigned)"""
    msg_cfg = config["message"]
    jira_base = config["jira"]["base_url"].rstrip("/")
    at_assignee = msg_cfg.get("at_assignee", True)
    now = datetime.now(UTC)

    # 先收集所有 assignee 邮箱，一次性解析 open_id（手动映射/缓存/API）
    assignee_emails = []
    for issue in issues:
        fields = issue.get("fields", {})
        assignee = fields.get("assignee")
        if assignee and assignee.get("emailAddress"):
            assignee_emails.append(assignee["emailAddress"])
    open_id_map = resolve_open_ids(config, assignee_emails) if at_assignee else {}

    groups = {}  # {email: {"name", "user_id", "issues": [...]}}
    unassigned = []

    for issue in issues:
        key = issue.get("key", "?")
        fields = issue.get("fields", {})
        summary = fields.get("summary", "无标题")
        status = fields.get("status", {})
        status_name = status.get("name", "未知") if isinstance(status, dict) else str(status)
        assignee = fields.get("assignee", None)
        priority = fields.get("priority", {})
        priority_name = priority.get("name", "") if isinstance(priority, dict) else ""

        issue_url = f"{jira_base}/browse/{key}"
        dwell = _fmt_dwell(_assignee_dwell(issue, now))

        if assignee and assignee.get("emailAddress"):
            email = assignee["emailAddress"]
            display_name = assignee.get("displayName", email)
            user_id = open_id_map.get(email, "")
            issue_data = {
                "key": key,
                "summary": summary,
                "status": status_name,
                "priority": priority_name,
                "url": issue_url,
                "dwell": dwell,
                "assignee_name": display_name,
            }
            if email not in groups:
                groups[email] = {
                    "name": display_name,
                    "user_id": user_id,
                    "issues": [],
                }
            groups[email]["issues"].append(issue_data)
        else:
            unassigned.append({
                "key": key,
                "summary": summary,
                "status": status_name,
                "priority": priority_name,
                "url": issue_url,
                "dwell": dwell,
                "assignee_name": "未指派",
            })

    return groups, unassigned


CARD_SIZE_LIMIT = 28 * 1024    # 单卡片上限（飞书互动卡片约 30KB）
CARD_CHUNK_LIMIT = 26 * 1024   # 拆分后每片上限，留余量


def _build_card_msg(title, elements, feishu_cfg, template="blue"):
    """构建一条飞书互动卡片消息体（Schema 2.0）。

    elements 是 body 元素列表（div/column_set/markdown/hr/note 等）。
    config.style.text_size.normal_v2 供元素 text_size:"normal_v2" 引用。
    """
    card = {
        "schema": "2.0",
        "config": {
            "update_multi": True,
            "style": {"text_size": {"normal_v2": {"default": "normal",
                                                  "pc": "normal", "mobile": "heading"}}},
        },
        "header": {
            "title": {"tag": "plain_text", "content": title},
            "template": template,
        },
        "body": {"elements": elements},
    }
    msg_body = {"msg_type": "interactive", "card": card}
    secret = feishu_cfg.get("secret", "")
    if secret:
        timestamp = str(int(time.time()))
        sign = gen_feishu_sign(timestamp, secret)
        msg_body["timestamp"] = timestamp
        msg_body["sign"] = sign
    return msg_body


def _card_size(body):
    """卡片消息体序列化后的字节数"""
    return len(json.dumps(body, ensure_ascii=False).encode("utf-8"))


def _can_at(user_id):
    """只有 open_id（ou_ 开头）才能在飞书 webhook 里真正 @。
    邮箱前缀/用户名填进去会被当成无效 user_id，渲染成空 @，所以不是 ou_ 就不发 at 标签。
    """
    return bool(user_id) and str(user_id).startswith("ou_")


def _md_escape(text):
    """转义 lark_md 特殊字符，避免标题里的 *[]() 等破坏渲染。"""
    if not text:
        return ""
    for ch in ("\\", "`", "*", "_", "[", "]", "(", ")", "<", ">", "!"):
        text = text.replace(ch, "\\" + ch)
    return text


def _issue_line_md(idx, issue):
    """单条 issue 的 lark_md 行：序号 + 票号(链接) + 描述 + 优先级，末尾灰色字放阶段+停留时间。

    格式：1. [SWIM-100029](url) 描述（优先级）  [阶段] · 停留3天5时
    阶段字符从行首移到末尾；阶段+停留时间用灰色字，与前面的描述区分。
    """
    key = issue["key"]
    url = issue["url"]
    summary = _md_escape(issue.get("summary", ""))
    priority = _md_escape(issue.get("priority", ""))
    status = _md_escape(issue.get("status", ""))
    dwell = _md_escape(issue.get("dwell", ""))
    line = f"{idx}. [{key}]({url}) {summary}"
    if priority:
        line += f"（{priority}）"
    tail = f"[{status}]"
    if dwell:
        tail += f" · 停留 {dwell}"
    line += f'  <font color="grey">{tail}</font>'
    return line


MAX_ELEMENTS_PER_CARD = 30  # 飞书单卡元素数保守上限


def _fits(elems, feishu_cfg):
    """元素列表能否放进一张卡：元素数与大小都不超限。"""
    if len(elems) > MAX_ELEMENTS_PER_CARD:
        return False
    return _card_size(_build_card_msg("t", elems, feishu_cfg)) <= CARD_CHUNK_LIMIT


def _person_chunks(header, issues, feishu_cfg):
    """把一个人的 issues 拆成若干元素块，每块 = [header, issues_div] 且能放进一张卡。

    issues_div 是 lark_md，内容为该批 issue 行（序号在该人内连续）。
    行少则一块；太多则按行拆，每块带 header。
    """
    if not issues:
        return []

    def _block(batch, start_idx):
        lines = "\n".join(_issue_line_md(i, it) for i, it in enumerate(batch, start=start_idx))
        return [header, {"tag": "div", "text": {"tag": "lark_md", "content": lines}}]

    whole = _block(issues, 1)
    if _fits(whole, feishu_cfg):
        return [whole]
    chunks = []
    batch = []
    start = 1
    for it in issues:
        batch.append(it)
        trial = _block(batch, start)
        if not _fits(trial, feishu_cfg) and len(batch) > 1:
            batch.pop()
            chunks.append(_block(batch, start))
            start += len(batch)
            batch = [it]
    if batch:
        chunks.append(_block(batch, start))
    return chunks


def _person_header(group, at_assignee):
    """单人标题元素：名字 + 数量（可 @）。"""
    name = group["name"]
    uid = group["user_id"]
    head = f"👤 {name}（{len(group['issues'])} 个）"
    if at_assignee and _can_at(uid):
        head += f' <at user_id="{uid}"></at>'
    return {"tag": "div", "text": {"tag": "lark_md", "content": head}}


def _person_summary_line(group, at_assignee):
    """总览里单人一行：名字 + 数量（可 @）。"""
    name = group["name"]
    uid = group["user_id"]
    line = f"👤 {name}（{len(group['issues'])} 个）"
    if at_assignee and _can_at(uid):
        line += f' <at user_id="{uid}"></at>'
    return line


def _overview_table(groups, unassigned, at_assignee):
    """概览表格：负责人 | 数量，每行一个人（负责人列 lark_md 可 @），含未指派行。"""
    columns = [
        {"data_type": "lark_md", "name": "assignee", "display_name": "负责人",
         "horizontal_align": "left", "width": "70%"},
        {"data_type": "text", "name": "count", "display_name": "数量",
         "horizontal_align": "left", "width": "30%"},
    ]
    rows = []
    for _email, group in groups.items():
        name = group["name"]
        uid = group["user_id"]
        cell = f"👤 {name}"
        if at_assignee and _can_at(uid):
            cell += f' <at user_id="{uid}"></at>'
        rows.append({"assignee": cell, "count": str(len(group["issues"]))})
    if unassigned:
        rows.append({"assignee": "⚠️ 未指派", "count": str(len(unassigned))})
    return {
        "tag": "table",
        "columns": columns,
        "rows": rows,
        "row_height": "32px",
        "header_style": {"background_style": "none", "bold": True, "lines": 1},
        "page_size": 50,
        "margin": "0px 0px 0px 0px",
    }


MAX_TABLES_PER_CARD = 5  # 飞书每卡表格数量上限（用户确认）


def build_feishu_messages(config, issues):
    """构建飞书互动卡片消息列表（Schema 2.0）。

    每条 issue 用 column_set 样式（票号链接｜状态着色｜停留时间灰色 + 下方描述），
    按人分组、人名标题在前。不用 table，故无表格数量限制；按卡片大小/元素数分卡。首卡带概览。
    """
    groups, unassigned = group_issues_by_assignee(config, issues)

    feishu_cfg = config["feishu"]
    msg_cfg = config["message"]
    keyword = feishu_cfg.get("keyword", "")
    at_assignee = msg_cfg.get("at_assignee", True)
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    # 概览：总数 div + 每人数量表格（负责人｜数量，可 @）
    overview_els = [
        {"tag": "div", "text": {"tag": "lark_md",
         "content": f"📊 看板概览：共 {len(issues)} 个 Issue"}},
        _overview_table(groups, unassigned, at_assignee),
    ]

    # 收集每人的元素块（行多则拆多块，每块带 header）+ 未指派
    chunks = []
    for _email, group in groups.items():
        if not group["issues"]:
            continue
        chunks.extend(_person_chunks(_person_header(group, at_assignee),
                                     group["issues"], feishu_cfg))
    if unassigned:
        head = {"tag": "div", "text": {"tag": "lark_md",
                "content": f"⚠️ 未指派（{len(unassigned)} 个）"}}
        chunks.extend(_person_chunks(head, unassigned, feishu_cfg))

    messages = []
    title = f"{keyword} | Jira看板状态 ({now})"
    current = []
    overview_added = False

    def _flush():
        nonlocal current, overview_added
        if not current:
            return
        els = (list(overview_els) if not overview_added else []) + current
        overview_added = True
        idx = len(messages) + 1
        sub_title = title if idx == 1 else f"{title}（续{idx - 1}）"
        messages.append((f"卡片{idx}", _build_card_msg(sub_title, els, feishu_cfg)))
        current = []

    for chk in chunks:
        trial = current + chk
        if current and not _fits(trial, feishu_cfg):
            _flush()
            current = list(chk)
        else:
            current = trial
    _flush()

    return messages


# ─── 发送到飞书 ────────────────────────────────────────────

def send_to_feishu(webhook_url, msg_body):
    """通过 webhook 发送消息到飞书群"""
    try:
        resp = requests.post(webhook_url, json=msg_body, timeout=30, verify=False)
        data = resp.json()
        code = data.get("code", data.get("StatusCode", -1))
        if code == 0:
            _LOG("✅ 飞书消息发送成功！")
            return True
        else:
            _LOG(f"❌ 飞书发送失败: code={code}, msg={data.get('msg', '')}")
            _LOG(f"   完整响应: {data}")
            # 常见错误码说明
            if code == 19024:
                _LOG("   → 消息内容未包含自定义关键词，请在消息中包含关键词")
            elif code == 19021:
                _LOG("   → 签名校验失败，请检查 secret 配置")
            elif code == 19022:
                _LOG("   → IP 不在白名单内")
            return False
    except Exception as e:
        _LOG(f"❌ 飞书发送异常: {e}")
        return False


# ─── 主流程 ────────────────────────────────────────────────

def run_test(config, log=print):
    """测试 Jira 连通性。返回 True/False。"""
    set_log(log)
    jira_cfg = config["jira"]
    _base, _token = jira_creds(jira_cfg)
    jira = JiraClient(_base, _token)
    _LOG("=" * 50)
    _LOG("测试 Jira 连通性")
    _LOG("=" * 50)
    return jira.test_connection()


def run_push(config, log=print, dry_run=False):
    """执行一次推送（dry_run=True 时只预览不发送）。

    返回 dict：{ok, total, messages_built, sent}。
    """
    set_log(log)
    jira_cfg = config["jira"]
    feishu_cfg = config["feishu"]

    _base, _token = jira_creds(jira_cfg)
    jira = JiraClient(_base, _token)

    _LOG("=" * 50)
    _LOG(f"Jira → 飞书推送开始 ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})"
         + ("【预览 DRY-RUN】" if dry_run else ""))
    _LOG("=" * 50)

    if not jira.test_connection():
        _LOG("❌ Jira 连接失败，请检查配置")
        return {"ok": False, "total": 0, "messages_built": 0, "sent": 0}

    jql_filter = jira_cfg.get("jql_filter", "")
    max_results = jira_cfg.get("max_results", 200)

    if not jql_filter:
        _LOG("❌ 未配置 JQL 语句")
        _LOG("   请在 config.json 中设置 jira.jql_filter")
        return {"ok": False, "total": 0, "messages_built": 0, "sent": 0}

    _LOG("\n🔍 通过 JQL 搜索 Issue...")
    _LOG(f"   JQL: {jql_filter}")
    issues = jira.search_issues(jql_filter, max_results)

    _LOG(f"   获取到 {len(issues)} 个 Issue")

    if not issues:
        _LOG("⚠️ 没有符合条件的 Issue，跳过推送")
        return {"ok": True, "total": 0, "messages_built": 0, "sent": 0}

    _LOG("\n📝 构建飞书富文本消息...")
    messages = build_feishu_messages(config, issues)

    if dry_run:
        _LOG("\n" + "=" * 50)
        _LOG(f"DRY RUN - 消息预览（共 {len(messages)} 条，未发送到飞书）")
        _LOG("=" * 50)
        for i, item in enumerate(messages):
            if isinstance(item, tuple):
                label, msg = item
            else:
                label, msg = f"消息 {i+1}", item
            _LOG(f"\n--- 消息 {i+1}/{len(messages)}: {label} ---")
            msg_json = json.dumps(msg, ensure_ascii=False, indent=2)
            msg_size = len(msg_json.encode("utf-8"))
            _LOG(f"大小: {msg_size / 1024:.1f} KB")
            _LOG(msg_json[:2000])
            if len(msg_json) > 2000:
                _LOG(f"  ...（已截断显示，完整长度 {len(msg_json)} 字符）")
        return {"ok": True, "total": len(issues), "messages_built": len(messages), "sent": 0}

    _LOG(f"\n📤 发送到飞书群（共 {len(messages)} 条消息）...")
    success_count = 0
    for i, item in enumerate(messages):
        if isinstance(item, tuple):
            label, msg = item
        else:
            label, msg = f"消息 {i+1}", item
        msg_size = len(json.dumps(msg, ensure_ascii=False).encode("utf-8"))
        if send_to_feishu(feishu_cfg["webhook_url"], msg):
            _LOG(f"  [{i+1}/{len(messages)}] {label}（{msg_size / 1024:.1f} KB）✅")
            success_count += 1
        else:
            _LOG(f"  [{i+1}/{len(messages)}] {label}（{msg_size / 1024:.1f} KB）❌")
        # 多条消息间间隔 1 秒，避免飞书限流（5次/秒）
        if i < len(messages) - 1:
            time.sleep(1)

    _LOG(f"\n✅ 推送完成：{success_count}/{len(messages)} 条消息发送成功 "
         f"({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    return {"ok": success_count > 0, "total": len(issues),
            "messages_built": len(messages), "sent": success_count}


def gen_mapping_template(config, log=print):
    """从看板提取所有负责人，生成 user_mapping.json 模板。"""
    set_log(log)
    jira_cfg = config["jira"]
    _base, _token = jira_creds(jira_cfg)
    jira = JiraClient(_base, _token)
    _LOG("=" * 50)
    _LOG("生成用户映射模板")
    _LOG("=" * 50)
    if not jira.test_connection():
        _LOG("❌ Jira 连接失败，请检查配置")
        return
    jql_filter = jira_cfg.get("jql_filter", "")
    if not jql_filter:
        _LOG("❌ 请先在 config.json 中设置 jira.jql_filter")
        return
    _LOG("\n📋 通过 JQL 提取所有负责人...")
    _LOG(f"   JQL: {jql_filter}")
    issues = jira.search_issues(jql_filter, 500)
    groups, unassigned = group_issues_by_assignee(config, issues)
    mappings = {}
    for email, group in groups.items():
        mappings[email] = "ou_请替换"
        _LOG(f"  {group['name']:<10} → {email}")
    template = {
        "_说明": "将每个人的飞书 Open ID 填入对应邮箱后面。Open ID 格式为 ou_xxxxx",
        "mappings": mappings,
    }
    with open(MAPPING_PATH, "w", encoding="utf-8") as f:
        json.dump(template, f, ensure_ascii=False, indent=2)
    _LOG(f"\n✅ 映射模板已生成: {MAPPING_PATH}")
    _LOG(f"   共 {len(mappings)} 人，请将每人的飞书 Open ID 填入")
    _LOG("   获取 Open ID 方式：飞书管理后台 → 组织管理 → 成员列表 → 查看成员详情")


def main():
    # 解析命令行参数
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    test_jira = "--test-jira" in args
    gen_mapping = "--gen-mapping" in args

    config = load_config()

    # CLI 模式下日志直接走 print
    set_log(print)

    if test_jira:
        run_test(config, print)
        return

    if gen_mapping:
        gen_mapping_template(config, print)
        return

    run_push(config, print, dry_run=dry_run)


if __name__ == "__main__":
    main()
