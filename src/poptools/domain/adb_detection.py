"""Conservative, non-executing ADB analysis. Dynamic code needs an explicit declaration."""
from __future__ import annotations

import ast
import re
import shlex
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from poptools.domain.models import (
    AndroidDeviceMode,
    ExecutorKind,
    ParameterKind,
    ToolDefinition,
    ToolSection,
)

HOST_COMMANDS = {
    "devices", "version", "help", "start-server", "kill-server", "connect", "disconnect",
}
TARGET_OPTIONS = {"-s", "-t", "-d", "-e"}
VALUE_OPTIONS = {"-s", "-t", "-H", "-P", "-L"}


@dataclass(frozen=True)
class AdbAnalysis:
    uses_adb: bool = False
    needs_device: bool = False
    explicit_target: bool = False
    reason: str = "未识别到 ADB 调用；动态命令或外部封装可手动选择“使用”。"


def split_command(source: str) -> list[str]:
    lexer = shlex.shlex(source, posix=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    lexer.escape = ""
    try:
        return list(lexer)
    except ValueError:
        return []


def _is_adb(program: str) -> bool:
    return program.replace("\\", "/").rsplit("/", 1)[-1].casefold() in {"adb", "adb.exe"}


def _call(arguments: list[str]) -> tuple[bool, bool]:
    """Return (requires local selection, has an explicit target) for one invocation."""
    explicit = False
    index = 0
    while index < len(arguments) and arguments[index].startswith("-"):
        option = arguments[index]
        explicit |= option in TARGET_OPTIONS
        if option in VALUE_OPTIONS:
            index += 2
        else:
            index += 1
    command = arguments[index].casefold() if index < len(arguments) else "help"
    return command not in HOST_COMMANDS and not explicit, explicit


def _shell_segments(source: str, kind: ExecutorKind) -> list[list[str]]:
    """Tokenize command boundaries without interpreting strings as executable code.

    This is deliberately not a full shell parser. Here-documents / here-strings are
    skipped, and variable invocations are left for the manual declaration.
    """
    if kind == ExecutorKind.POWERSHELL:
        source = re.sub(r"(?ms)@(['\"])[ \t]*\r?\n.*?^\1@[^\n]*", "", source)
        source = re.sub(r"(?s)<#.*?#>", "", source)
    if kind == ExecutorKind.BASH:
        source = re.sub(r"(?m)\\\r?\n", " ", source)
        source = re.sub(
            r"(?ms)<<-?\s*['\"]?(\w+)['\"]?[^\n]*\n.*?^\1\s*$", "", source
        )
    if kind == ExecutorKind.POWERSHELL:
        source = re.sub(r"`\r?\n", " ", source)
    if kind == ExecutorKind.BATCH:
        source = re.sub(r"\^\r?\n", " ", source)
        source = "\n".join(
            line for line in source.splitlines()
            if not re.match(r"(?i)^\s*@?(?:rem(?:\s|$)|::)", line)
        )
    # A scanner retains newlines and treats quoted semicolons, pipes and comments
    # as literal arguments. In particular, `echo "adb shell"` never becomes a call.
    segments: list[list[str]] = []
    tokens: list[str] = []
    token = ""
    quote = ""
    escape = "`" if kind == ExecutorKind.POWERSHELL else "^" if kind == ExecutorKind.BATCH else "\\"
    i = 0
    while i < len(source):
        char = source[i]
        if char == escape and quote != "'" and i + 1 < len(source):
            next_char = source[i + 1]
            # Backslashes in Windows paths are literal, even inside quotes.
            if kind != ExecutorKind.BASH or next_char in '\\"$`;&| \n':
                token += next_char
                i += 2
                continue
        if quote:
            if char == quote:
                quote = ""
            else:
                token += char
        elif char in "\"'":
            if not token:
                token = "\0"
            quote = char
        elif char == "#" and not token and kind != ExecutorKind.BATCH:
            end = source.find("\n", i)
            i = len(source) if end < 0 else end - 1
        elif char in ";&|\n\r{}()":
            if token:
                tokens.append(token)
                token = ""
            if tokens:
                segments.append(tokens)
                tokens = []
            if char == "&":
                tokens = ["&"]
        elif char.isspace():
            if token:
                tokens.append(token)
                token = ""
        else:
            token += char
        i += 1
    if token:
        tokens.append(token)
    if tokens:
        segments.append(tokens)
    return segments


def _shell_calls(source: str, kind: ExecutorKind) -> list[list[str]]:
    calls: list[list[str]] = []
    for words in _shell_segments(source, kind):
        invocation = words[0] == "&"
        while words and (
            words[0].lstrip("@").casefold()
            in {"call", "then", "do", "else", "if", "elif", "!", "", "&"}
            or re.fullmatch(r"[A-Za-z_][\w]*=.*", words[0])
        ):
            words = words[1:]
        if (words and words[0].startswith("\0")
                and kind == ExecutorKind.POWERSHELL and not invocation):
            continue
        words = [word.lstrip("\0") for word in words]
        if words and _is_adb(words[0].lstrip("@")):
            calls.append(words[1:])
    return calls


def _python_calls(source: str) -> list[list[str]]:
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return []
    bindings: dict[str, object] = {}
    aliases: dict[str, str] = {}
    calls: list[list[str]] = []

    def literal(node: ast.AST) -> object:
        if isinstance(node, ast.Name):
            return bindings.get(node.id)
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        if isinstance(node, (ast.List, ast.Tuple)):
            return [literal(item) for item in node.elts]
        return None

    def name(node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            return aliases.get(node.id, node.id)
        if isinstance(node, ast.Attribute):
            return name(node.value) + "." + node.attr
        return ""

    class Visitor(ast.NodeVisitor):
        def visit_Import(self, node: ast.Import) -> None:
            for item in node.names:
                aliases[item.asname or item.name] = item.name

        def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
            for item in node.names:
                aliases[item.asname or item.name] = f"{node.module}.{item.name}"

        def visit_Assign(self, node: ast.Assign) -> None:
            value = literal(node.value)
            for target in node.targets:
                if isinstance(target, ast.Name):
                    bindings[target.id] = value
            self.generic_visit(node)

        def visit_Call(self, node: ast.Call) -> None:
            function = name(node.func)
            if function in {
                "subprocess.run", "subprocess.Popen", "subprocess.call",
                "subprocess.check_call", "subprocess.check_output", "os.system",
            }:
                argument = node.args[0] if node.args else next(
                    (kw.value for kw in node.keywords if kw.arg in {"args", "command"}), None
                )
                value = literal(argument) if argument is not None else None
                if isinstance(value, str):
                    calls.extend(_shell_calls(value, ExecutorKind.BASH))
                elif (isinstance(value, list) and value and isinstance(value[0], str)
                      and _is_adb(value[0])):
                    calls.append([item if isinstance(item, str) else "?" for item in value[1:]])
            self.generic_visit(node)

    Visitor().visit(tree)
    return calls


def analyze_adb(
    tool: ToolDefinition, resolve_source: Callable[[str], Path] | None = None,
) -> AdbAnalysis:
    executor = tool.executor
    if executor.android_device_mode == AndroidDeviceMode.NONE:
        return AdbAnalysis(reason="已声明不使用 Android 设备。")
    if executor.android_device_mode == AndroidDeviceMode.USE:
        return AdbAnalysis(True, True, reason="已声明使用 Android 设备。")
    requirements = {item.casefold() for item in executor.requirements}
    declared_required = "android_device" in requirements or any(
        p.kind == ParameterKind.ANDROID_DEVICE for p in tool.parameters
    )
    declared = declared_required or "adb" in requirements
    # Built-ins use dispatcher files shared by many actions. Their per-action
    # declarations are authoritative; scanning the dispatcher would mix actions.
    if tool.section == ToolSection.PRESET and declared:
        return AdbAnalysis(True, declared_required, reason="根据工具的 Android 依赖声明。")
    source = executor.command
    kind = executor.kind
    words = split_command(source)
    unreadable = False
    if resolve_source and words and "\n" not in source:
        first = words[1] if words[0] in {"&", ".", "call"} and len(words) > 1 else words[0]
        suffix = Path(first).suffix.casefold()
        file_kind = {".py": ExecutorKind.PYTHON, ".ps1": ExecutorKind.POWERSHELL,
                     ".sh": ExecutorKind.BASH, ".bat": ExecutorKind.BATCH,
                     ".cmd": ExecutorKind.BATCH}.get(suffix)
        if file_kind:
            try:
                path = resolve_source(first)
                # Bound UI-thread work; never follow arbitrary module imports.
                if path.stat().st_size > 1024 * 1024:
                    raise OSError("script too large")
                try:
                    source = path.read_text(encoding="utf-8-sig")
                except UnicodeError:
                    source = path.read_text(encoding="gb18030")
                kind = file_kind
            except (OSError, ValueError, UnicodeError):
                unreadable = True
    if kind == ExecutorKind.PYTHON:
        calls = _python_calls(source)
    elif kind == ExecutorKind.PROCESS:
        calls = [[*words[1:], *executor.args]] if words and _is_adb(words[0]) else []
    elif kind in {ExecutorKind.BASH, ExecutorKind.BATCH, ExecutorKind.POWERSHELL}:
        calls = _shell_calls(source, kind)
    else:
        calls = []
    results = [_call(args) for args in calls]
    if results:
        return AdbAnalysis(
            True, declared_required or any(r[0] for r in results), any(r[1] for r in results),
            f"识别到 {len(results)} 处 ADB 调用。",
        )
    if declared:
        return AdbAnalysis(True, declared_required, reason="根据工具的 Android 依赖声明。")
    return AdbAnalysis(reason="无法读取外部脚本；可手动选择“使用”。" if unreadable
                       else AdbAnalysis().reason)
