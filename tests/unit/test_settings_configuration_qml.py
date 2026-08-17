from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_settings_exposes_configuration_import_export_and_folder_actions() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    settings = (QML_ROOT / "components" / "SettingsDialog.qml").read_text(encoding="utf-8")
    color_dialog = (QML_ROOT / "components" / "ColorPickerDialog.qml").read_text(
        encoding="utf-8"
    )

    assert 'text: "客制"' in settings
    assert 'text: "Python 运行环境"' in settings
    assert 'text: "终端功能"' in settings
    assert "root.controller.terminalEnabled" in settings
    assert "root.terminalEnableRequested()" in settings
    assert "root.controller.saveTerminalEnabled(false)" in settings
    assert "onTerminalEnableRequested: window.requestTerminalEnable()" in main
    assert 'text: "应用专属"' in settings
    assert 'Python Doctor、依赖安装和脚本运行始终使用' not in settings
    assert 'Theme.primaryContainer' in settings
    assert settings.count('AppComboBox {') == 2
    assert 'text: "脚本并发数量"' in settings
    assert 'objectName: "customScriptConcurrencyBox"' in settings
    assert "root.controller.customScriptConcurrency - 1" in settings
    assert "root.controller.saveCustomScriptConcurrency(currentValue)" in settings
    for value in range(1, 6):
        assert f'{{ "label": "{value} 个", "value": {value} }}' in settings
    assert "QtQuick.Dialogs" not in settings
    assert "ColorPickerDialog {" in settings
    assert "function openMiddlePanelColorDialog()" in settings
    assert "middlePanelColorDialog.openWithColor(" in settings
    assert "onClicked: root.openMiddlePanelColorDialog()" in settings
    assert 'text: "选择中栏颜色"' in color_dialog
    assert 'objectName: "middlePanelColorConfirmButton"' in color_dialog
    assert 'objectName: "middlePanelColorCancelButton"' in color_dialog
    assert color_dialog.count("radius: 24") >= 2
    assert "ctx.clip()" in color_dialog
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
    assert "width: 800" not in main
    assert "height: 600" not in main
    assert "startupWindowWidth" not in settings
    assert "startupWindowHeight" not in settings
    assert "startupWindowCentered" not in settings
    assert "saveStartupWindowSize" not in settings
    assert 'text: "冷启动窗口尺寸"' not in settings
    assert 'text: "屏幕居中"' not in settings
    assert 'text: "外观"' in settings
    assert '"label": "跟随系统"' in settings
    assert '"label": "浅色"' in settings
    assert '"label": "深色"' in settings
    assert "root.controller.saveThemeMode(currentValue)" in settings
    assert 'property: "darkMode"' in main
    assert "Screen.virtualX" not in main
    assert "Screen.virtualY" not in main
