from pathlib import Path

ROOT = Path(__file__).parents[2]


def test_manual_release_workflow_builds_and_publishes_ota_assets() -> None:
    workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    assert "workflow_dispatch:" in workflow
    assert "contents: write" in workflow
    assert "inputs.version" not in workflow
    assert (
        ".\\packaging\\build.ps1 -SkipInstaller "
        "-VersionOverride $env:RELEASE_VERSION"
    ) in workflow
    assert "dist/泡泡工具箱.exe" in workflow
    assert "dist/泡泡工具箱.exe.sha256" in workflow
    assert '"release", "create", $env:RELEASE_TAG' in workflow
