from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def test_package_main_file_can_be_run_directly(tmp_path: Path) -> None:
    project_root = Path(__file__).parents[2]
    entrypoint = project_root / "src" / "poptools" / "__main__.py"
    worker = tmp_path / "worker.py"
    worker.write_text("print('worker-ok')", encoding="utf-8")

    result = subprocess.run(
        [sys.executable, str(entrypoint), "--worker", str(worker)],
        cwd=project_root,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )

    assert result.returncode == 0, result.stderr
    assert "worker-ok" in result.stdout


def test_worker_code_executes_inline_python_source() -> None:
    project_root = Path(__file__).parents[2]
    entrypoint = project_root / "src" / "poptools" / "__main__.py"
    source = 'if __name__ == "__main__":\n    print("hello world")'

    result = subprocess.run(
        [sys.executable, str(entrypoint), "--worker-code", source],
        cwd=project_root,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )

    assert result.returncode == 0, result.stderr
    assert "hello world" in result.stdout
