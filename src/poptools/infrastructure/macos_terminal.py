from __future__ import annotations

import shlex
import shutil
import subprocess
import sys
import uuid
from collections.abc import Mapping
from pathlib import Path


class MacOSTerminalLauncher:
    """Open Terminal.app with a process-local PopTools tool environment."""

    def __init__(self, runtime_dir: Path) -> None:
        self._scripts_dir = runtime_dir / "terminal"

    def open(
        self,
        working_directory: Path,
        environment: Mapping[str, str],
    ) -> Path:
        if sys.platform != "darwin":
            raise RuntimeError("系统 Terminal 启动器仅适用于 macOS")
        opener = shutil.which("open") or "/usr/bin/open"
        if not Path(opener).is_file():
            raise RuntimeError("未找到 macOS open 命令")

        self._scripts_dir.mkdir(parents=True, exist_ok=True)
        script = self._scripts_dir / f"poptools-{uuid.uuid4().hex}.command"
        script.write_text(
            self._startup_script(script, working_directory, environment),
            encoding="utf-8",
        )
        script.chmod(0o700)
        try:
            subprocess.Popen(
                [opener, "-a", "Terminal", str(script)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError:
            script.unlink(missing_ok=True)
            raise
        return script

    @staticmethod
    def _startup_script(
        script: Path,
        working_directory: Path,
        environment: Mapping[str, str],
    ) -> str:
        exports = []
        for name in (
            "PATH",
            "PYTHONPATH",
            "VIRTUAL_ENV",
            "POPTOOLS_PYTHON",
            "POPTOOLS_PIP",
            "POPTOOLS_PYTHON_SITE_PACKAGES",
            "POPTOOLS_ADB",
            "POPTOOLS_SCRCPY",
            "SCRCPY_SERVER_PATH",
            "PYTHONUTF8",
            "PYTHONIOENCODING",
            "PYTHONUNBUFFERED",
        ):
            value = environment.get(name)
            if value:
                exports.append(f"export {name}={shlex.quote(value)}")
        return "\n".join(
            (
                "#!/bin/sh",
                "set -e",
                *exports,
                f"cd -- {shlex.quote(str(working_directory))}",
                f"rm -f -- {shlex.quote(str(script))}",
                'exec "${SHELL:-/bin/zsh}" -i',
                "",
            )
        )
