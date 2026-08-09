import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).parents[2]


def test_build_downloads_and_verifies_the_private_python_runtime_package() -> None:
    build = (PROJECT_ROOT / "packaging" / "build.ps1").read_text(encoding="utf-8")
    manifest = json.loads(
        (
            PROJECT_ROOT
            / "src"
            / "poptools"
            / "resources"
            / "vendor"
            / "python"
            / "python-runtime.json"
        ).read_text(encoding="utf-8")
    )

    assert manifest["version"] == "3.13.14"
    assert manifest["url"].startswith("https://www.nuget.org/")
    assert len(manifest["sha256"]) == 64
    assert "Invoke-WebRequest" in build
    assert "Get-FileHash" in build
