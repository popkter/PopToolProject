from pathlib import Path


def test_main_qml_shows_python_doctor_warnings_in_a_dialog() -> None:
    qml_root = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"
    source = (qml_root / "Main.qml").read_text(encoding="utf-8")
    dialog = (qml_root / "components" / "PythonDoctorDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "function onPythonDoctorWarning(message)" in source
    assert "function onPythonDoctorInstallSuggestion(packages)" in source
    assert "function onPythonDependencyInstallFinished(success, message)" in source
    assert "id: pythonDoctorDialogLoader" in source
    assert "active: false" in source
    assert 'text: "检查 Python 依赖"' in dialog
    assert 'width: Math.min(540' in dialog
    assert 'height: Math.min(460' in dialog
    assert 'text: "Python 环境目录"' in dialog
    assert 'text: root.controller.pythonEnvironmentDirectory' in dialog
    assert 'readOnly: true' in dialog
    assert '"确认安装"' in dialog
    assert "installPythonDependencies" in dialog
