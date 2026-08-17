from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_update_dialog_and_startup_check_are_wired() -> None:
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    dialog = (QML_ROOT / "components" / "UpdateDialog.qml").read_text(encoding="utf-8")

    assert "updateController.checkForUpdates()" in main
    assert "function onUpdateAvailable()" in main
    assert "updateDialogLoader" in main
    assert 'text: "下次提醒"' in dialog
    assert 'text: "跳过此版本"' in dialog
    assert 'text: "立即更新"' in dialog
    assert 'text: "取消下载"' in dialog
    assert 'text: "安装并重启"' in dialog
    assert "root.controller.downloadUpdate()" in dialog
    assert "root.controller.skipVersion()" in dialog
    assert "root.controller.installAndRestart()" in dialog
    assert dialog.count("radius: 24") >= 8
