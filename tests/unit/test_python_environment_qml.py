from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_settings_can_select_managed_or_custom_python() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")

    assert 'id: pythonSettingsDialog' not in main
    assert 'id: settingsDialog' in main
    assert 'id: pythonProviderBox' in settings
    assert '"value": "managed"' in settings
    assert '"value": "custom"' in settings
    assert "root.controller.choosePythonExecutable()" in settings
    assert "customPythonField.text = root.controller.customPythonExecutable" in settings
    assert "root.controller.savePythonEnvironment(" in settings
    assert "root.controller.pythonEnvironmentStatus" in settings


def test_python_environment_changes_require_restart_without_settings_finish_button() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")
    restart_dialog = (QML_ROOT / "components" / "PythonRestartDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "pythonEnvironmentModified" in settings
    assert 'root.controller.pythonValidationRunning ? "正在验证" : "应用更改"' in settings
    assert "root.restartRequested()" in settings
    assert "onRestartRequested: pythonRestartDialog.open()" in main
    assert 'id: pythonRestartDialog' in main
    assert "Popup.NoAutoClose" in restart_dialog
    assert "padding: 0" in restart_dialog
    assert 'title: "重启应用"' not in restart_dialog
    assert 'text: "重启应用"' in restart_dialog
    assert "Layout.preferredHeight: 72" in restart_dialog
    assert "radius: Theme.radiusLarge" in restart_dialog
    assert "root.controller.restartApplication()" in restart_dialog
    assert 'text: "完成"' not in settings
