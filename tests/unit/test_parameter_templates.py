import pytest

from poptools.domain.models import ParameterDefinition, ParameterKind
from poptools.domain.parameter_templates import (
    extract_parameter_ids,
    render_template,
    synchronize_parameters,
)


def test_chinese_placeholder_generates_text_input() -> None:
    parameters = synchronize_parameters(["adb shell ${输入密码}"])

    assert [parameter.id for parameter in parameters] == ["输入密码"]
    assert parameters[0].label == "输入密码"
    assert parameters[0].kind == ParameterKind.TEXT
    assert parameters[0].required is True
    assert render_template("adb shell ${输入密码}", {"输入密码": "adbd1234"}) == (
        "adb shell adbd1234"
    )


def test_parameter_order_is_stable_and_existing_metadata_is_kept() -> None:
    existing = ParameterDefinition(
        id="device",
        label="选择设备",
        required=False,
        placeholder="自动选择",
    )
    parameters = synchronize_parameters(
        ["adb -s ${device} shell ${动作}", "${device}"],
        [existing],
    )

    assert [parameter.id for parameter in parameters] == ["device", "动作"]
    assert parameters[0].label == "选择设备"
    assert parameters[0].required is False


def test_invalid_parameter_name_is_rejected() -> None:
    with pytest.raises(ValueError, match="只能包含"):
        extract_parameter_ids(["adb shell ${输入 密码}"])

def test_placeholder_default_is_used_and_prefills_parameter() -> None:
    template = "adb shell pidof ${进程关键字=com.zeekr.speech}"

    parameters = synchronize_parameters([template])

    assert [parameter.id for parameter in parameters] == ["进程关键字"]
    assert parameters[0].default == "com.zeekr.speech"
    assert render_template(template, {}) == "adb shell pidof com.zeekr.speech"
    assert render_template(template, {"进程关键字": "com.example.app"}) == (
        "adb shell pidof com.example.app"
    )


def test_default_value_can_contain_equals_sign() -> None:
    template = "tool --filter ${筛选条件=type=voice}"

    assert render_template(template, {}) == "tool --filter type=voice"


def test_conflicting_defaults_are_rejected() -> None:
    with pytest.raises(ValueError, match="多个不同的默认值"):
        synchronize_parameters(["${目标=first} ${目标=second}"])


def test_declared_parameter_uses_label_default_and_reusable_id() -> None:
    template = (
        "pVal value1: ${这是一个变量=TEST83972NT000114}\n"
        "adb shell setprop persist.sys.vin ${value1}\n"
        "adb shell setprop persist.sys.ihuid ${value1}\n"
        "adb shell setprop persist.tbox.imsi ${value1}"
    )

    parameters = synchronize_parameters([template])

    assert [parameter.id for parameter in parameters] == ["value1"]
    assert parameters[0].label == "这是一个变量"
    assert parameters[0].default == "TEST83972NT000114"
    assert render_template(template, {"value1": "CUSTOM"}) == (
        "adb shell setprop persist.sys.vin CUSTOM\n"
        "adb shell setprop persist.sys.ihuid CUSTOM\n"
        "adb shell setprop persist.tbox.imsi CUSTOM"
    )


def test_equals_declaration_creates_only_one_input_for_repeated_references() -> None:
    template = (
        "pVal vin = ${请输入vin=TEST83972NT000114}\n\n\n"
        "adb shell setprop persist.sys.vin ${vin}\n"
        "adb shell setprop persist.sys.ihuid ${vin}\n"
        "adb shell setprop persist.tbox.imsi ${vin}"
    )

    parameters = synchronize_parameters([template])

    assert [(parameter.id, parameter.label, parameter.default) for parameter in parameters] == [
        ("vin", "请输入vin", "TEST83972NT000114")
    ]
    assert render_template(template, {"vin": "VIN999"}) == (
        "\n\nadb shell setprop persist.sys.vin VIN999\n"
        "adb shell setprop persist.sys.ihuid VIN999\n"
        "adb shell setprop persist.tbox.imsi VIN999"
    )


def test_declaration_can_supply_value_used_by_an_argument() -> None:
    parameters = synchronize_parameters(
        ["pVal value1: ${车辆识别码=VIN123}\necho ready", "${value1}"]
    )

    assert [(parameter.id, parameter.label, parameter.default) for parameter in parameters] == [
        ("value1", "车辆识别码", "VIN123")
    ]
    assert render_template("${value1}", {"value1": "VIN999"}) == "VIN999"


def test_existing_quick_placeholder_syntax_remains_supported() -> None:
    template = "adb shell setprop persist.sys.vin ${车辆识别码=VIN123}"

    parameters = synchronize_parameters([template])

    assert [(parameter.id, parameter.label, parameter.default) for parameter in parameters] == [
        ("车辆识别码", "车辆识别码", "VIN123")
    ]
    assert render_template(template, {"车辆识别码": "VIN999"}).endswith("VIN999")


def test_conflicting_parameter_declarations_are_rejected() -> None:
    with pytest.raises(ValueError, match="多个不同的声明"):
        synchronize_parameters(
            ["pVal value1: ${车辆识别码=VIN123}\npVal value1: ${用户编号=USER123}"]
        )
