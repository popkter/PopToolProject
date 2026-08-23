from pathlib import Path

PROJECT_ROOT = Path(__file__).parents[2]


def test_installer_can_finish_closing_legacy_tray_builds() -> None:
    installer = (PROJECT_ROOT / "packaging" / "poptools.iss").read_text(
        encoding="utf-8"
    )

    assert "CloseApplications=force" in installer
    assert "RestartApplications=no" in installer
    assert "function CloseRunningApplication(): Boolean;" in installer
    assert "FindWindowByWindowName('{#MyAppName}')" in installer
    assert "taskkill /PID %d /T /F" in installer
    assert "if CurPageID = wpReady then" in installer


def test_application_accepts_restart_manager_shutdown_requests() -> None:
    entrypoint = (PROJECT_ROOT / "src" / "poptools" / "main.py").read_text(
        encoding="utf-8"
    )

    assert "app.commitDataRequest.connect(" in entrypoint
    assert "tray_controller.quit_application()" in entrypoint
