from __future__ import annotations

import os
import sys
from pathlib import Path


def _run() -> int:
    if __package__ in {None, ""}:
        entrypoint = Path(__file__).resolve()
        project_root = entrypoint.parents[2]
        project_python = (
            project_root / ".venv" / "Scripts" / "python.exe"
            if os.name == "nt"
            else project_root / ".venv" / "bin" / "python"
        )
        if (
            sys.prefix == sys.base_prefix
            and project_python.exists()
            and Path(sys.executable).resolve() != project_python.resolve()
        ):
            os.execv(
                str(project_python),
                [str(project_python), str(entrypoint), *sys.argv[1:]],
            )
        sys.path.insert(0, str(project_root / "src"))

    from poptools.main import main

    return main()


if __name__ == "__main__":
    raise SystemExit(_run())
