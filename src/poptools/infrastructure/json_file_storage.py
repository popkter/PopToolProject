from __future__ import annotations

import json
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any


class JsonFileStorage:
    """Shared atomic JSON file operations for JSON-backed adapters."""

    def __init__(self, backups_dir: Path) -> None:
        self.backups_dir = backups_dir
        self.backups_dir.mkdir(parents=True, exist_ok=True)

    def write(self, target: Path, value: dict[str, Any]) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        handle, temp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
        try:
            with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
                json.dump(value, stream, ensure_ascii=False, indent=2)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp_name, target)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)

    def backup(self, path: Path, suffix: str) -> Path | None:
        if not path.exists():
            return None
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        destination = self.backups_dir / f"{path.name}.{stamp}.{suffix}"
        shutil.copy2(path, destination)
        return destination
