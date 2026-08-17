from pathlib import Path

QML_ROOT = Path(__file__).parents[2] / "src" / "poptools" / "ui" / "qml"


def test_parameter_form_supports_choices_and_booleans() -> None:
    main = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert 'modelData.kind === "choice" ? choiceField' in main
    assert 'modelData.kind === "boolean" ? booleanField' in main
    assert "id: choiceField" in main
    assert "id: booleanField" in main
    assert "onCurrentTextChanged" in main
    assert "onToggled: root.parameterValues[modelData.id] = checked" in main


def test_all_parameter_inputs_use_the_fixed_model_height() -> None:
    main = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert "readonly property real parameterInputHeight: 54" in main
    assert "readonly property real singleLineHeight: root.parameterInputHeight" in main
    assert "height: singleLineHeight" in main
    assert "implicitHeight: 122" not in main
    assert "contentHeight + topPadding + bottomPadding" not in main
    assert main.count("implicitHeight: parameterInputLoader.singleLineHeight") == 4


def test_parameter_flow_uses_the_available_content_width() -> None:
    main = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert "Flow {" in main
    assert "id: parameterFlow" in main
    assert "width: parameterFlow.width" in main


def test_secret_parameter_uses_password_echo_mode() -> None:
    main = (QML_ROOT / "components" / "CommandWorkspace.qml").read_text(encoding="utf-8")

    assert 'modelData.kind === "secret"' in main
    assert "? TextInput.Password : TextInput.Normal" in main
