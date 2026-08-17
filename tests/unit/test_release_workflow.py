from pathlib import Path

ROOT = Path(__file__).parents[2]


def test_manual_release_workflow_builds_and_publishes_ota_assets() -> None:
    workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    assert "workflow_dispatch:" in workflow
    assert "contents: write" in workflow
    assert 'version: "0.12.3"' in workflow
    assert "INPUT_VERSION" not in workflow
    assert "inputs.version" not in workflow
    assert "Invalid pyproject.toml version" in workflow
    assert "China Standard Time" in workflow
    assert "yyyy-MM-dd" in workflow
    assert (
        ".\\packaging\\build.ps1 -SkipInstaller "
        "-VersionOverride $env:RELEASE_VERSION"
    ) in workflow
    assert "Get-FileHash" in workflow
    assert "Application code version $codeVersion does not match" in workflow
    assert "from poptools import __version__; print(__version__)" in workflow
    assert "Upload test report on failure" in workflow
    assert "build/test-results/pytest.xml" in workflow
    assert "dist/泡泡工具箱.exe" in workflow
    assert "dist/泡泡工具箱.exe.sha256" in workflow
    assert '"release", "create", $env:RELEASE_TAG' in workflow
    assert '"--target", $env:RELEASE_TARGET' in workflow
    assert '"--generate-notes"' in workflow


def test_build_script_accepts_a_full_release_version_override() -> None:
    build_script = (ROOT / "packaging" / "build.ps1").read_text(encoding="utf-8-sig")

    assert '[string]$VersionOverride = ""' in build_script
    assert "VersionOverride must use YYYY-MM-DD_x.x.x" in build_script
    assert "does not match pyproject.toml version $BaseVersion" in build_script
    assert "ensurepip --default-pip" in build_script
    assert '"--junitxml=$JunitReport"' in build_script


def test_runtime_registers_the_generated_build_version_with_qt() -> None:
    main = (ROOT / "src" / "poptools" / "main.py").read_text(encoding="utf-8")

    assert "from poptools import __version__" in main
    assert "QCoreApplication.setApplicationVersion(__version__)" in main


def test_project_semantic_version_is_the_release_source_of_truth() -> None:
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")

    assert 'version = "0.2.0"' in pyproject
