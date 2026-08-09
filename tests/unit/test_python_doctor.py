from pathlib import Path

from poptools.infrastructure.python_doctor import PythonDoctor


def test_doctor_reports_only_unavailable_third_party_imports() -> None:
    available = {"requests", "pandas"}
    doctor = PythonDoctor(lambda module: object() if module in available else None)

    result = doctor.check(
        "import os\nimport requests\nimport missing_sdk.client\nfrom pandas import DataFrame"
    )

    assert result.checked_modules == ("missing_sdk", "os", "pandas", "requests")
    assert result.missing_modules == ("missing_sdk",)
    assert result.syntax_error == ""


def test_doctor_recognizes_modules_next_to_a_script_file(tmp_path: Path) -> None:
    (tmp_path / "local_helper.py").write_text("VALUE = 1", encoding="utf-8")
    script = tmp_path / "example.py"
    script.write_text("import local_helper\nimport absent_package", encoding="utf-8")
    doctor = PythonDoctor(lambda _module: None)

    result = doctor.check(str(script))

    assert result.missing_modules == ("absent_package",)


def test_doctor_reports_python_syntax_errors() -> None:
    result = PythonDoctor().check("from")

    assert result.missing_modules == ()
    assert "第 1 行" in result.syntax_error


def test_doctor_still_reports_an_unavailable_interpreter_without_imports() -> None:
    result = PythonDoctor().check("print('hello')")

    assert result.environment_error == "Python 解释器不可用"
