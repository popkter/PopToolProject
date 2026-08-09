from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_settings_exposes_configuration_import_export_and_folder_actions() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")

    assert 'text: "客制功能脚本"' in settings
    assert 'text: "Python 运行环境"' in settings
    assert 'text: "Doctor 与脚本共用"' in settings
    assert 'Python Doctor、依赖安装和脚本运行始终使用' not in settings
    assert 'Theme.primaryContainer' in settings
    assert settings.count('AppComboBox {') == 2
    assert 'middlePanelColorDialog.open()' in settings
    assert 'text: "取色"' in settings
    assert "root.controller.configurationDirectory" in settings
    assert "root.controller.openConfigurationDirectory()" in settings
    assert "root.controller.importConfiguration()" in settings
    assert "root.controller.exportConfiguration()" in settings
    assert 'icon: "folder_open"' in settings
    assert 'text: "导入脚本"' in settings
    assert 'text: "导出脚本"' in settings
    assert "config.json" not in settings
    assert "root.controller.configurationStatus" in settings
    assert "备份并替换默认目录" in settings
    assert "width: 800" in main
    assert "height: 600" in main
    assert "root.controller.startupWindowWidth" in settings
    assert "root.controller.startupWindowHeight" in settings
    assert "root.controller.startupWindowCentered" in settings
    assert "root.controller.saveStartupWindowSize(" in settings
    assert 'text: "冷启动窗口尺寸"' in settings
    assert 'text: "屏幕居中"' in settings
    assert 'text: "外观"' in settings
    assert '"label": "跟随系统"' in settings
    assert '"label": "浅色"' in settings
    assert '"label": "深色"' in settings
    assert "root.controller.saveThemeMode(currentValue)" in settings
    assert 'property: "darkMode"' in main
    assert "Screen.virtualX" in main
    assert "Screen.virtualY" in main
