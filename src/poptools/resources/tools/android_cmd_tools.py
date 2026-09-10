from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def _executable(name: str) -> str:
    if name == "adb":
        configured = os.environ.get("POPTOOLS_ADB", "").strip()
        if configured:
            return configured
    candidate = shutil.which(name)
    if candidate:
        return candidate
    if name == "fastboot":
        adb = os.environ.get("POPTOOLS_ADB", "").strip()
        if adb:
            sibling = Path(adb).with_name("fastboot.exe" if os.name == "nt" else "fastboot")
            if sibling.is_file():
                return str(sibling)
    raise RuntimeError(f"未找到 {name} 运行环境")


def _serial() -> str:
    serial = os.environ.get("ANDROID_SERIAL", "").strip()
    if not serial:
        raise RuntimeError("未选择 Android 设备")
    return serial


def adb_args(*args: str, device: bool = True) -> list[str]:
    command = [_executable("adb")]
    if device:
        command.extend(["-s", _serial()])
    command.extend(args)
    return command


def _run(
    command: list[str],
    *,
    capture: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=capture,
    )
    if capture:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, command)
    return result


def _capture(*args: str) -> str:
    result = subprocess.run(
        adb_args(*args),
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, result.args)
    return result.stdout


def _output_dir() -> Path:
    value = os.environ.get("POPTOOLS_OUTPUT_DIR", "").strip()
    directory = Path(value) if value else Path.cwd()
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def _timestamp() -> str:
    return datetime.now().strftime("%Y-%m-%d-%H-%M-%S")


def _safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._") or "android"


def _print_saved(path: Path) -> None:
    print(f"已保存到：{path}")


def _simple(args: argparse.Namespace) -> None:
    commands: dict[str, tuple[str, ...]] = {
        "power": ("shell", "input", "keyevent", "26"),
        "back": ("shell", "input", "keyevent", "4"),
        "home": ("shell", "input", "keyevent", "3"),
        "recents": ("shell", "input", "keyevent", "187"),
        "menu": ("shell", "input", "keyevent", "82"),
        "shutdown": ("shell", "reboot", "-p"),
        "reboot": ("reboot",),
        "developer-settings": (
            "shell",
            "am",
            "start",
            "-a",
            "android.settings.APPLICATION_DEVELOPMENT_SETTINGS",
        ),
        "device-info-settings": (
            "shell",
            "am",
            "start",
            "-a",
            "android.settings.DEVICE_INFO_SETTINGS",
        ),
        "top-activity-content": ("shell", "dumpsys", "activity", "top"),
        "clear-data": ("shell", "pm", "clear", args.package),
        "force-stop": ("shell", "am", "force-stop", args.package),
        "freeze": ("shell", "pm", "disable-user", "--user", "0", args.package),
        "unfreeze": ("shell", "pm", "enable", args.package),
        "grant": ("shell", "pm", "grant", args.package, args.permission),
        "revoke": ("shell", "pm", "revoke", args.package, args.permission),
        "properties": ("shell", "getprop"),
        "serial": ("get-serialno",),
    }
    _run(adb_args(*commands[args.action]), capture=True)


def _input_text(args: argparse.Namespace) -> None:
    encoded = args.text.replace("%", "%25").replace(" ", "%s")
    _run(adb_args("shell", "input", "text", encoded), capture=True)


def _tap(args: argparse.Namespace) -> None:
    _run(adb_args("shell", "input", "tap", str(args.x), str(args.y)), capture=True)


def _adb_server(args: argparse.Namespace) -> None:
    if args.action == "restart-adb":
        _run(adb_args("kill-server", device=False), capture=True, check=False)
        _run(adb_args("start-server", device=False), capture=True)
    elif args.action == "kill-adb":
        _run(adb_args("kill-server", device=False), capture=True)
    else:
        _run(adb_args("version", device=False), capture=True)


def _fastboot_version(_args: argparse.Namespace) -> None:
    _run([_executable("fastboot"), "--version"], capture=True)


def _open_url(args: argparse.Namespace) -> None:
    _run(
        adb_args("shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", args.url),
        capture=True,
    )


def _open_activity(args: argparse.Namespace) -> None:
    _run(adb_args("shell", "am", "start", "-n", args.activity), capture=True)


def _install(args: argparse.Namespace) -> None:
    apk = Path(args.apk).expanduser()
    if not apk.is_file():
        raise RuntimeError(f"APK 文件不存在：{apk}")
    command = ["install"]
    if args.replace == "yes":
        command.append("-r")
    command.append(str(apk.resolve()))
    _run(adb_args(*command), capture=True)


def _uninstall(args: argparse.Namespace) -> None:
    command = ["uninstall"]
    if args.keep_data == "yes":
        command.append("-k")
    command.append(args.package)
    _run(adb_args(*command), capture=True)


def _set_proxy(args: argparse.Namespace) -> None:
    _run(
        adb_args("shell", "settings", "put", "global", "http_proxy", f"{args.host}:{args.port}"),
        capture=True,
    )


def _clear_proxy(_args: argparse.Namespace) -> None:
    for key in (
        "http_proxy",
        "global_http_proxy_host",
        "global_http_proxy_port",
        "global_http_proxy_exclusion_list",
    ):
        _run(adb_args("shell", "settings", "delete", "global", key), capture=True, check=False)
    _run(
        adb_args("shell", "settings", "put", "global", "http_proxy", ":0"),
        capture=True,
        check=False,
    )
    print("全局代理已清除")


def _manage_files(args: argparse.Namespace) -> None:
    remote = args.remote_path
    if args.operation == "list":
        _run(adb_args("shell", "ls", "-la", remote), capture=True)
    elif args.operation == "mkdir":
        _run(adb_args("shell", "mkdir", "-p", remote), capture=True)
    elif args.operation == "delete":
        _run(adb_args("shell", "rm", "-rf", remote), capture=True)
    elif args.operation == "push":
        local = Path(args.local_path).expanduser()
        if not local.exists():
            raise RuntimeError(f"本地路径不存在：{local}")
        _run(adb_args("push", str(local.resolve()), remote), capture=True)
    else:
        destination = Path(args.local_path).expanduser() if args.local_path else _output_dir()
        destination.mkdir(parents=True, exist_ok=True)
        _run(adb_args("pull", remote, str(destination.resolve())), capture=True)
        _print_saved(destination.resolve())


def _screenshot(_args: argparse.Namespace) -> None:
    path = _output_dir() / f"screenshot-{_timestamp()}.png"
    with path.open("wb") as output:
        result = subprocess.run(adb_args("exec-out", "screencap", "-p"), stdout=output, check=False)
    if result.returncode != 0:
        path.unlink(missing_ok=True)
        raise subprocess.CalledProcessError(result.returncode, result.args)
    _print_saved(path)


def _record(args: argparse.Namespace) -> None:
    remote = f"/sdcard/poptools-recording-{_timestamp()}.mp4"
    path = _output_dir() / Path(remote).name
    try:
        _run(
            adb_args("shell", "screenrecord", "--time-limit", str(args.seconds), remote),
            capture=True,
        )
        _run(adb_args("pull", remote, str(path)), capture=True)
        _print_saved(path)
    finally:
        _run(adb_args("shell", "rm", "-f", remote), capture=True, check=False)


def _wireless(args: argparse.Namespace) -> None:
    if args.action == "wireless-on":
        _run(adb_args("tcpip", str(args.port)), capture=True)
        addresses = _capture("shell", "ip", "-o", "-4", "addr", "show", "wlan0")
        match = re.search(r"\binet\s+([0-9.]+)", addresses)
        if match:
            print(f"无线调试地址：{match.group(1)}:{args.port}")
    elif args.target:
        _run(adb_args("disconnect", args.target, device=False), capture=True)
    else:
        _run(adb_args("disconnect", device=False), capture=True)


def _top_package(_args: argparse.Namespace) -> None:
    output = _capture("shell", "dumpsys", "activity", "activities")
    patterns = (
        r"mResumedActivity:.*?\s([A-Za-z0-9._]+)/(?:[A-Za-z0-9._$]+)",
        r"topResumedActivity=.*?\s([A-Za-z0-9._]+)/(?:[A-Za-z0-9._$]+)",
        r"mFocusedApp=.*?\s([A-Za-z0-9._]+)/(?:[A-Za-z0-9._$]+)",
    )
    for pattern in patterns:
        match = re.search(pattern, output)
        if match:
            print(match.group(1))
            return
    raise RuntimeError("未能识别栈顶 Activity 包名")


def _export_apk(args: argparse.Namespace) -> None:
    output = _capture("shell", "pm", "path", args.package)
    remote_paths = [
        line.partition(":")[2].strip()
        for line in output.splitlines()
        if line.startswith("package:")
    ]
    if not remote_paths:
        raise RuntimeError(f"未找到应用安装包：{args.package}")
    target = _output_dir() / f"{_safe_name(args.package)}-{_timestamp()}"
    target.mkdir(parents=True, exist_ok=True)
    for remote in remote_paths:
        _run(adb_args("pull", remote, str(target / Path(remote).name)), capture=True)
    _print_saved(target)


def _export_anr(_args: argparse.Namespace) -> None:
    target = _output_dir() / f"anr-{_timestamp()}"
    target.mkdir(parents=True, exist_ok=True)
    _run(adb_args("pull", "/data/anr/.", str(target)), capture=True)
    _print_saved(target)


def _screen_info(_args: argparse.Namespace) -> None:
    print("屏幕尺寸：")
    _run(adb_args("shell", "wm", "size"), capture=True)
    print("屏幕密度：")
    _run(adb_args("shell", "wm", "density"), capture=True)
    print("显示服务：")
    output = _capture("shell", "dumpsys", "display")
    for line in output.splitlines():
        if any(key in line for key in ("DisplayDeviceInfo", "mBaseDisplayInfo", "refreshRate")):
            print(line.strip())


def _cpu_arch(_args: argparse.Namespace) -> None:
    output = _capture("shell", "getprop", "ro.product.cpu.abilist").strip()
    if not output:
        output = _capture("shell", "getprop", "ro.product.cpu.abi").strip()
    print(output)


def _logcat(args: argparse.Namespace) -> None:
    command = adb_args("logcat", "-v", "threadtime")
    if args.filter:
        command.extend(["-s", args.filter])
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert process.stdout is not None
    for line in process.stdout:
        print(line, end="", flush=True)
    if process.wait() != 0:
        raise subprocess.CalledProcessError(process.returncode, command)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="PopTools Android 命令预设执行器")
    subparsers = parser.add_subparsers(dest="action", required=True)

    for name in (
        "power",
        "back",
        "home",
        "recents",
        "menu",
        "shutdown",
        "reboot",
        "developer-settings",
        "device-info-settings",
        "top-activity-content",
        "properties",
        "serial",
    ):
        command = subparsers.add_parser(name)
        command.set_defaults(handler=_simple)

    command = subparsers.add_parser("input-text")
    command.add_argument("text")
    command.set_defaults(handler=_input_text)
    command = subparsers.add_parser("tap")
    command.add_argument("x", type=int)
    command.add_argument("y", type=int)
    command.set_defaults(handler=_tap)

    for name in ("restart-adb", "kill-adb", "adb-version"):
        command = subparsers.add_parser(name)
        command.set_defaults(handler=_adb_server)
    command = subparsers.add_parser("fastboot-version")
    command.set_defaults(handler=_fastboot_version)

    command = subparsers.add_parser("open-url")
    command.add_argument("url")
    command.set_defaults(handler=_open_url)
    command = subparsers.add_parser("open-activity")
    command.add_argument("activity")
    command.set_defaults(handler=_open_activity)

    command = subparsers.add_parser("install")
    command.add_argument("apk")
    command.add_argument("replace", choices=("yes", "no"))
    command.set_defaults(handler=_install)
    command = subparsers.add_parser("uninstall")
    command.add_argument("package")
    command.add_argument("keep_data", choices=("yes", "no"))
    command.set_defaults(handler=_uninstall)
    command = subparsers.add_parser("set-proxy")
    command.add_argument("host")
    command.add_argument("port", type=int)
    command.set_defaults(handler=_set_proxy)
    command = subparsers.add_parser("clear-proxy")
    command.set_defaults(handler=_clear_proxy)

    command = subparsers.add_parser("manage-files")
    command.add_argument("operation", choices=("list", "push", "pull", "mkdir", "delete"))
    command.add_argument("remote_path")
    command.add_argument("local_path")
    command.set_defaults(handler=_manage_files)
    command = subparsers.add_parser("screenshot")
    command.set_defaults(handler=_screenshot)
    command = subparsers.add_parser("record-screen")
    command.add_argument("seconds", type=int, choices=range(1, 181))
    command.set_defaults(handler=_record)

    command = subparsers.add_parser("wireless-on")
    command.add_argument("port", type=int)
    command.set_defaults(handler=_wireless)
    command = subparsers.add_parser("wireless-off")
    command.add_argument("target")
    command.set_defaults(handler=_wireless)

    for name in ("clear-data", "force-stop", "freeze", "unfreeze"):
        command = subparsers.add_parser(name)
        command.add_argument("package")
        command.set_defaults(handler=_simple)
    for name in ("grant", "revoke"):
        command = subparsers.add_parser(name)
        command.add_argument("package")
        command.add_argument("permission")
        command.set_defaults(handler=_simple)

    for name, handler in (
        ("top-package", _top_package),
        ("export-apk", _export_apk),
        ("export-anr", _export_anr),
        ("screen-info", _screen_info),
        ("cpu-arch", _cpu_arch),
    ):
        command = subparsers.add_parser(name)
        if name == "export-apk":
            command.add_argument("package")
        command.set_defaults(handler=handler)
    command = subparsers.add_parser("logcat")
    command.add_argument("filter")
    command.set_defaults(handler=_logcat)
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = build_parser().parse_args(argv)
        args.handler(args)
        return 0
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError) as exc:
        print(f"执行失败：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
