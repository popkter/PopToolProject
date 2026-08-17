from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_settings_uses_only_the_application_python_environment() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")

    assert 'id: pythonSettingsDialog' not in main
    assert 'id: settingsDialog' in main
    assert 'text: "应用专属"' in settings
    assert "pythonProviderBox" not in settings
    assert "choosePythonExecutable" not in settings
    assert "savePythonEnvironment" not in settings
    assert "root.controller.pythonEnvironmentStatus" in settings


def test_python_environment_no_longer_requires_restart_configuration() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")
    assert "pythonRestartDialog" not in main
    assert "pythonEnvironmentModified" not in settings
    assert "savePythonEnvironment" not in settings


def test_user_guide_explains_managed_dependencies_and_terminal() -> None:
    guide = (QML_ROOT / "components" / "UserGuideDialog.qml").read_text(
        encoding="utf-8"
    )

    assert 'text: "3. 自动配置 Python 依赖"' in guide
    assert "新建、编辑或运行 Python 脚本时" in guide
    assert 'text: "4. 开启并使用内置终端"' in guide
    assert "python --version、pip list、pip install 包名" in guide
    assert "同一个应用专属环境" in guide
