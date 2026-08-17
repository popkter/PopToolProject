from __future__ import annotations

import ast
import json
import shlex
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

PIP_PACKAGE_NAME_OVERRIDES = {
    "bs4": "beautifulsoup4",
    "Crypto": "pycryptodome",
    "cv2": "opencv-python",
    "dateutil": "python-dateutil",
    "dotenv": "python-dotenv",
    "fitz": "PyMuPDF",
    "jwt": "PyJWT",
    "lunar_python": "lunar-python",
    "PIL": "Pillow",
    # wexpect still imports the legacy module removed from setuptools 82+.
    "pkg_resources": "setuptools<82",
    "serial": "pyserial",
    "sklearn": "scikit-learn",
    "yaml": "PyYAML",
}


def pip_package_names(modules: tuple[str, ...] | list[str]) -> tuple[str, ...]:
    """Translate import names to pip distribution names without duplicates."""
    names: list[str] = []
    for module in modules:
        package = PIP_PACKAGE_NAME_OVERRIDES.get(module, module)
        if package not in names:
            names.append(package)
    return tuple(names)


@dataclass(frozen=True)
class PythonDoctorResult:
    checked_modules: tuple[str, ...] = ()
    missing_modules: tuple[str, ...] = ()
    syntax_error: str = ""
    environment_error: str = ""

    @property
    def healthy(self) -> bool:
        return not self.missing_modules and not self.syntax_error and not self.environment_error


@dataclass(frozen=True)
class PythonDoctorPlan:
    checked_modules: tuple[str, ...] = ()
    modules_to_check: tuple[str, ...] = ()
    immediate_result: PythonDoctorResult | None = None


class PythonDoctor:
    """Inspect source statically, then query the exact interpreter used to run it."""

    def __init__(
        self,
        module_finder: Callable[[str], object | None] | None = None,
    ) -> None:
        self._module_finder = module_finder

    def check(self, script: str, executable: str | None = None) -> PythonDoctorResult:
        plan = self.prepare(script)
        if plan.immediate_result is not None:
            return plan.immediate_result
        if executable:
            missing, error = self._find_missing_with(executable, plan.modules_to_check)
            return PythonDoctorResult(
                checked_modules=plan.checked_modules,
                missing_modules=missing,
                environment_error=error,
            )
        return PythonDoctorResult(
            checked_modules=plan.checked_modules,
            environment_error="Python 解释器不可用",
        )

    def prepare(self, script: str) -> PythonDoctorPlan:
        """Perform local analysis and return an interpreter probe plan without blocking."""
        source, script_directory = self._load_source(script)
        try:
            tree = ast.parse(source)
        except SyntaxError as exc:
            location = f"第 {exc.lineno} 行" if exc.lineno else "未知位置"
            return PythonDoctorPlan(
                immediate_result=PythonDoctorResult(
                    syntax_error=f"{location}：{exc.msg}"
                )
            )

        modules = self._imported_top_level_modules(tree)
        local_modules = {
            module for module in modules if self._is_local(module, script_directory)
        }
        modules_to_check = tuple(
            module
            for module in modules
            if module not in local_modules
            and module not in sys.stdlib_module_names
            and module not in sys.builtin_module_names
        )
        if self._module_finder is not None:
            missing = tuple(
                module for module in modules_to_check if not self._is_available_locally(module)
            )
            return PythonDoctorPlan(
                immediate_result=PythonDoctorResult(
                    checked_modules=modules,
                    missing_modules=missing,
                )
            )
        return PythonDoctorPlan(
            checked_modules=modules,
            modules_to_check=modules_to_check,
        )

    @staticmethod
    def probe_source() -> str:
        return (
            "import contextlib, importlib, io, json, sys\n"
            "missing = []\n"
            "for name in sys.argv[1:]:\n"
            "    try:\n"
            "        with contextlib.redirect_stdout(io.StringIO()):\n"
            "            importlib.import_module(name)\n"
            "    except ModuleNotFoundError as exc:\n"
            "        missing.append(exc.name or name)\n"
            "    except ImportError:\n"
            "        missing.append(name)\n"
            "print(json.dumps(missing))\n"
        )

    @staticmethod
    def complete_probe(
        plan: PythonDoctorPlan,
        exit_code: int,
        stdout: str,
        stderr: str,
    ) -> PythonDoctorResult:
        if exit_code != 0:
            detail = stderr.strip() or f"退出码 {exit_code}"
            return PythonDoctorResult(
                checked_modules=plan.checked_modules,
                environment_error=f"依赖检查失败：{detail}",
            )
        try:
            missing = json.loads(stdout)
        except json.JSONDecodeError:
            return PythonDoctorResult(
                checked_modules=plan.checked_modules,
                environment_error="Python 解释器返回了无法识别的检查结果",
            )
        if not isinstance(missing, list) or not all(isinstance(item, str) for item in missing):
            return PythonDoctorResult(
                checked_modules=plan.checked_modules,
                environment_error="Python 解释器返回了无效的检查结果",
            )
        return PythonDoctorResult(
            checked_modules=plan.checked_modules,
            missing_modules=tuple(missing),
        )

    @staticmethod
    def _load_source(script: str) -> tuple[str, Path | None]:
        candidate = Path(script.strip().strip('"'))
        if "\n" not in script and candidate.is_file():
            return candidate.read_text(encoding="utf-8-sig"), candidate.parent

        if "\n" not in script:
            try:
                parts = shlex.split(script, posix=False)
            except ValueError:
                parts = []
            if parts:
                candidate = Path(parts[0].strip('"'))
                if candidate.is_file():
                    return candidate.read_text(encoding="utf-8-sig"), candidate.parent
        return script, None

    @staticmethod
    def _imported_top_level_modules(tree: ast.AST) -> tuple[str, ...]:
        modules: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                modules.update(alias.name.partition(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
                modules.add(node.module.partition(".")[0])
        modules.discard("__future__")
        return tuple(sorted(modules))

    @staticmethod
    def _is_local(module: str, script_directory: Path | None) -> bool:
        return bool(
            script_directory is not None
            and (
                (script_directory / f"{module}.py").is_file()
                or (script_directory / module / "__init__.py").is_file()
            )
        )

    def _is_available_locally(self, module: str) -> bool:
        if module in sys.stdlib_module_names or module in sys.builtin_module_names:
            return True
        try:
            return self._module_finder is not None and self._module_finder(module) is not None
        except (ImportError, AttributeError, ValueError):
            return False

    @staticmethod
    def _find_missing_with(
        executable: str, modules: tuple[str, ...]
    ) -> tuple[tuple[str, ...], str]:
        if not modules:
            return (), ""
        source = PythonDoctor.probe_source()
        try:
            completed = subprocess.run(
                [executable, "-c", source, *modules],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=20,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return (), f"无法启动 Python 解释器：{exc}"
        result = PythonDoctor.complete_probe(
            PythonDoctorPlan(modules_to_check=modules),
            completed.returncode,
            completed.stdout,
            completed.stderr,
        )
        return result.missing_modules, result.environment_error
