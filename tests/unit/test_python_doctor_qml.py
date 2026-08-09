from pathlib import Path


def test_main_qml_shows_python_doctor_warnings_in_a_dialog() -> None:
    qml_root = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"
    source = (qml_root / "Main.qml").read_text(encoding="utf-8")
    dialog = (qml_root / "components" / "PythonDoctorDialog.qml").read_text(
        encoding="utf-8"
    )

    assert "function onPythonDoctorWarning(message)" in source
    assert "id: pythonDoctorDialog" in source
    assert 'title: "Python Doctor"' in dialog
