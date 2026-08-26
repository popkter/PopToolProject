from __future__ import annotations

import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass

from poptools.domain.models import ParameterDefinition, ParameterKind, ParameterOption

PLACEHOLDER_PATTERN = re.compile(r"\$\{([^{}]+)\}")
DECLARATION_PATTERN = re.compile(
    r"^[ \t]*pVal[ \t]+(?P<id>[^\s:=]+)[ \t]*(?::|=)[ \t]*"
    r"\$\{(?P<definition>[^{}\r\n]+)\}[ \t]*(?:\r?\n|$)",
    re.MULTILINE,
)


@dataclass(frozen=True)
class _ParsedPlaceholder:
    parameter_id: str
    default: str | None
    options: tuple[ParameterOption, ...] = ()


def _validate_parameter_id(parameter_id: str) -> None:
    if not parameter_id or not parameter_id.replace("_", "").isalnum():
        raise ValueError(
            f"参数名称“{parameter_id}”只能包含中文、字母、数字或下划线；"
            "如需设置默认值，请使用 ${参数名:默认值}"
        )


def _parse_choice_options(content: str) -> tuple[ParameterOption, ...]:
    parts = content.split("|")
    if len(parts) < 2 or not all("=" in part for part in parts):
        return ()

    options: list[ParameterOption] = []
    labels: set[str] = set()
    for part in parts:
        label, _, value = part.partition("=")
        normalized_label = label.strip()
        normalized_value = value.strip()
        if not normalized_label or not normalized_value:
            raise ValueError("下拉选项必须使用“显示文字=实际值”格式，且两侧不能为空")
        if normalized_label in labels:
            raise ValueError(f"下拉选项“{normalized_label}”重复")
        labels.add(normalized_label)
        options.append(ParameterOption(label=normalized_label, value=normalized_value))
    return tuple(options)


def _parse_placeholder(content: str) -> _ParsedPlaceholder:
    """Parse current colon syntax while retaining legacy equals syntax."""

    colon_index = content.find(":")
    equals_index = content.find("=")
    if colon_index >= 0 and (equals_index < 0 or colon_index < equals_index):
        name, _, definition = content.partition(":")
        parameter_id = name.strip()
        _validate_parameter_id(parameter_id)
        options = _parse_choice_options(definition)
        if options:
            return _ParsedPlaceholder(parameter_id, options[0].value, options)
        return _ParsedPlaceholder(parameter_id, definition)

    # Compatibility with templates created before the title/definition separator
    # changed to ':', including ${name=default} and ${on=1|off=0}.
    legacy_options = _parse_choice_options(content)
    if legacy_options:
        parameter_id = legacy_options[0].label
        _validate_parameter_id(parameter_id)
        return _ParsedPlaceholder(parameter_id, legacy_options[0].value, legacy_options)

    name, separator, default = content.partition("=")
    parameter_id = name.strip()
    _validate_parameter_id(parameter_id)
    return _ParsedPlaceholder(parameter_id, default if separator else None)


def _parse_declarations(
    template: str,
) -> list[tuple[str, str, str | None, tuple[ParameterOption, ...]]]:
    declarations: list[tuple[str, str, str | None, tuple[ParameterOption, ...]]] = []
    for match in DECLARATION_PATTERN.finditer(template):
        parameter = _parse_placeholder(match.group("id"))
        definition = _parse_placeholder(match.group("definition"))
        declarations.append(
            (
                parameter.parameter_id,
                definition.parameter_id,
                definition.default,
                definition.options,
            )
        )
    return declarations


def _script_body(template: str) -> str:
    """Remove pVal metadata lines before a script is executed or scanned."""

    return DECLARATION_PATTERN.sub("", template)


def extract_parameter_ids(templates: Iterable[str]) -> list[str]:
    """Extract unique ${parameter} names in display order."""

    result: list[str] = []
    for template in templates:
        for parameter_id, _, _, _ in _parse_declarations(template):
            if parameter_id not in result:
                result.append(parameter_id)
        for match in PLACEHOLDER_PATTERN.finditer(_script_body(template)):
            parameter_id = _parse_placeholder(match.group(1)).parameter_id
            if parameter_id not in result:
                result.append(parameter_id)
    return result


def synchronize_parameters(
    templates: Iterable[str],
    existing: Sequence[ParameterDefinition] = (),
) -> list[ParameterDefinition]:
    """Keep existing metadata and create text fields for new placeholders."""

    existing_by_id = {parameter.id: parameter for parameter in existing}
    parameters: list[ParameterDefinition] = []
    parsed: dict[
        str, tuple[str, str | None, bool, tuple[ParameterOption, ...]]
    ] = {}
    materialized_templates = list(templates)

    for template in materialized_templates:
        for parameter_id, label, default, options in _parse_declarations(template):
            current = parsed.get(parameter_id)
            declaration = (label, default, True, options)
            if current is not None and current != declaration:
                raise ValueError(f"参数“{parameter_id}”设置了多个不同的声明")
            parsed[parameter_id] = declaration

    for template in materialized_templates:
        for match in PLACEHOLDER_PATTERN.finditer(_script_body(template)):
            placeholder = _parse_placeholder(match.group(1))
            parameter_id = placeholder.parameter_id
            default = placeholder.default
            if parameter_id not in parsed:
                parsed[parameter_id] = (
                    parameter_id,
                    default,
                    False,
                    placeholder.options,
                )
            elif default is not None:
                label, current_default, declared, options = parsed[parameter_id]
                if current_default is None:
                    parsed[parameter_id] = (label, default, declared, placeholder.options)
                elif current_default != default or options != placeholder.options:
                    raise ValueError(f"参数“{parameter_id}”设置了多个不同的默认值")

    for parameter_id, (label, default, declared, options) in parsed.items():
        existing_parameter = existing_by_id.get(parameter_id)
        if existing_parameter is not None:
            # Default, choice kind and options are derived from the current
            # template. They must be replaced rather than only filled in, or an
            # edited `${name:first=1|second=2}` keeps rendering as a choice after
            # it becomes `${name:value}`.
            updates: dict[str, object] = {
                "default": default or "",
                "options": list(options),
            }
            if declared:
                updates["label"] = label
            if options:
                updates["kind"] = ParameterKind.CHOICE
            elif existing_parameter.kind == ParameterKind.CHOICE:
                updates["kind"] = ParameterKind.TEXT
            parameters.append(existing_parameter.model_copy(update=updates))
            continue
        parameters.append(
            ParameterDefinition(
                id=parameter_id,
                label=label,
                required=True,
                default=default or "",
                placeholder=f"请输入{parameter_id}",
                kind=ParameterKind.CHOICE if options else ParameterKind.TEXT,
                options=list(options),
            )
        )
    return parameters


def render_template(template: str, values: dict[str, object]) -> str:
    def replace(match: re.Match[str]) -> str:
        placeholder = _parse_placeholder(match.group(1))
        return str(values.get(placeholder.parameter_id, placeholder.default or ""))

    return PLACEHOLDER_PATTERN.sub(replace, _script_body(template))


def update_parameter_default(template: str, parameter_id: str, default: str) -> str:
    """Persist a text parameter default back into its placeholder definition."""

    _validate_parameter_id(parameter_id)
    if any(character in default for character in "{}\r\n"):
        raise ValueError("默认值不能包含花括号或换行")

    replacements: list[tuple[int, int, str]] = []
    declaration_ranges: list[tuple[int, int]] = []
    declaration_found = False
    for match in DECLARATION_PATTERN.finditer(template):
        declaration_ranges.append(match.span())
        declared_parameter = _parse_placeholder(match.group("id"))
        if declared_parameter.parameter_id != parameter_id:
            continue
        definition = _parse_placeholder(match.group("definition"))
        if definition.options:
            raise ValueError("选择框不能通过文本默认值按钮修改")
        replacement = (
            f"{definition.parameter_id}:{default}" if default else definition.parameter_id
        )
        parsed_replacement = _parse_placeholder(replacement)
        if parsed_replacement.options:
            raise ValueError("该默认值会被识别成选择框，请修改字符串内容")
        start, end = match.span("definition")
        replacements.append((start, end, replacement))
        declaration_found = True

    if not declaration_found:
        for match in PLACEHOLDER_PATTERN.finditer(template):
            if any(start <= match.start() < end for start, end in declaration_ranges):
                continue
            placeholder = _parse_placeholder(match.group(1))
            if placeholder.parameter_id != parameter_id:
                continue
            if placeholder.options:
                raise ValueError("选择框不能通过文本默认值按钮修改")
            replacement = f"{parameter_id}:{default}" if default else parameter_id
            parsed_replacement = _parse_placeholder(replacement)
            if parsed_replacement.options:
                raise ValueError("该默认值会被识别成选择框，请修改字符串内容")
            start, end = match.span(1)
            replacements.append((start, end, replacement))

    if not replacements:
        raise ValueError(f"脚本中没有找到参数“{parameter_id}”的文本模板")

    updated = template
    for start, end, replacement in reversed(replacements):
        updated = updated[:start] + replacement + updated[end:]
    return updated
