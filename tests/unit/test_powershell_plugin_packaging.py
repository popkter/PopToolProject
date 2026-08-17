from __future__ import annotations

import json
from pathlib import Path


def test_powershell_plugin_manifest_is_packaged_and_checksum_pinned() -> None:
    project_root = Path(__file__).parents[2]
    manifest_path = (
        project_root
        / "src"
        / "poptools"
        / "resources"
        / "vendor"
        / "powershell-plugin.json"
    )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    spec = (project_root / "packaging" / "poptools.spec").read_text(encoding="utf-8")
    pyproject = (project_root / "pyproject.toml").read_text(encoding="utf-8")

    assert manifest["version"].startswith("7.")
    for architecture in ("x64", "arm64"):
        package = manifest["packages"][architecture]
        assert package["url"].startswith(
            "https://github.com/PowerShell/PowerShell/releases/download/"
        )
        assert len(package["sha256"]) == 64
    assert 'PACKAGE / "resources" / "vendor"' in spec
    assert '"resources/vendor/*"' in pyproject
