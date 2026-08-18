from pathlib import Path

ROOT = Path(__file__).parents[2]


def test_manual_release_workflow_builds_and_publishes_ota_assets() -> None:
    workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    assert "workflow_dispatch:" in workflow
    assert "contents: write" in workflow
    assert "inputs.version" not in workflow
    assert ".\\packaging\\build.ps1 -VersionOverride" in workflow
    assert './packaging/build.sh --version' in workflow
    assert "choco install innosetup" in workflow
    assert "release-assets/PopTools.exe" in workflow
    assert "release-assets/PopTools.exe.sha256" in workflow
    assert "release-assets/PopTools-Setup.exe" in workflow
    assert "PopTools.exe#泡泡工具箱.exe" in workflow
    assert "PopTools-macos-arm64.zip" in workflow
    assert "PopTools-macos-x64.zip" in workflow
    assert "macos-15-intel" in workflow
    assert 'release create "$RELEASE_TAG"' in workflow
