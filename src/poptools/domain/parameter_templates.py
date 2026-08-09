from __future__ import annotations

import re
from collections.abc import Iterable, Sequence

from poptools.domain.models import ParameterDefinition

PLACEHOLDER_PATTERN = re.compile(r"\$\{([^{}]+)\}")
DECLARATION_PATTERN = re.compile(
    r"^[ \t]*pVal[ \t]+(?P<id>[^\s:=]+)[ \t]*(?::|=)[ \t]*"
    r"\$\{(?P<definition>[^{}\r\n]+)\}[ \t]*(?:\r?\n|$)",
    re.MULTILINE,
)


def _parse_placeholder(content: str) -> tuple[str, str | None]:
    """Parse ${name} or ${name=default}; only the first '=' is structural."""

    name, separator, default = content.partition("=")
    parameter_id = name.strip()
    if not parameter_id or not parameter_id.replace("_", "").isalnum():
        raise ValueError(
            f"参数名称“{parameter_id}”只能包含中文、字母、数字或下划线；"
            "如需设置默认值，请使用 ${参数名=默认值}"
        )
    return parameter_id, default if separator else None


def _parse_declarations(template: str) -> list[tuple[str, str, str | None]]:
    declarations: list[tuple[str, str, str | None]] = []
    for match in DECLARATION_PATTERN.finditer(template):
        parameter_id, _ = _parse_placeholder(match.group("id"))
        label, default = _parse_placeholder(match.group("definition"))
        declarations.append((parameter_id, label, default))
    return declarations


def _script_body(template: str) -> str:
    """Remove pVal metadata lines before a script is executed or scanned."""

    return DECLARATION_PATTERN.sub("", template)


def extract_parameter_ids(templates: Iterable[str]) -> list[str]:
    """Extract unique ${parameter} names in display order."""

    result: list[str] = []
    for template in templates:
        for parameter_id, _, _ in _parse_declarations(template):
            if parameter_id not in result:
                result.append(parameter_id)
        for match in PLACEHOLDER_PATTERN.finditer(_script_body(template)):
            parameter_id, _ = _parse_placeholder(match.group(1))
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
    parsed: dict[str, tuple[str, str | None, bool]] = {}
    materialized_templates = list(templates)

    for template in materialized_templates:
        for parameter_id, label, default in _parse_declarations(template):
            current = parsed.get(parameter_id)
            declaration = (label, default, True)
            if current is not None and current != declaration:
                raise ValueError(f"参数“{parameter_id}”设置了多个不同的声明")
            parsed[parameter_id] = declaration

    for template in materialized_templates:
        for match in PLACEHOLDER_PATTERN.finditer(_script_body(template)):
            parameter_id, default = _parse_placeholder(match.group(1))
            if parameter_id not in parsed:
                parsed[parameter_id] = (parameter_id, default, False)
            elif default is not None:
                label, current_default, declared = parsed[parameter_id]
                if current_default is None:
                    parsed[parameter_id] = (label, default, declared)
                elif current_default != default:
                    raise ValueError(f"参数“{parameter_id}”设置了多个不同的默认值")

    for parameter_id, (label, default, declared) in parsed.items():
        current = existing_by_id.get(parameter_id)
        if current is not None:
            updates: dict[str, str] = {}
            if declared:
                updates["label"] = label
            if default is not None:
                updates["default"] = default
            parameters.append(current.model_copy(update=updates) if updates else current)
            continue
        parameters.append(
            ParameterDefinition(
                id=parameter_id,
                label=label,
                required=True,
                default=default or "",
                placeholder=f"请输入{parameter_id}",
            )
        )
    return parameters


def render_template(template: str, values: dict[str, object]) -> str:
    def replace(match: re.Match[str]) -> str:
        parameter_id, default = _parse_placeholder(match.group(1))
        return str(values.get(parameter_id, default or ""))

    return PLACEHOLDER_PATTERN.sub(replace, _script_body(template))
