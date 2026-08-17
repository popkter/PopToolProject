from pathlib import Path

ROOT = Path(__file__).parents[2]


def test_manual_release_workflow_builds_and_publishes_ota_assets() -> None:
    workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    assert "workflow_dispatch:" in workflow
    assert "contents: write" in workflow
    assert 'version: "0.12.3"' in workflow
    assert ".\\packaging\\build.ps1 -SkipInstaller" in workflow
    assert "Get-FileHash" in workflow
    assert "dist/泡泡工具箱.exe" in workflow
    assert "dist/泡泡工具箱.exe.sha256" in workflow
    assert '"release", "create", $env:RELEASE_TAG' in workflow
    assert '"--target", $env:RELEASE_TARGET' in workflow
    assert '"--generate-notes"' in workflow
