---
name: poptool-script-parameters
description: Create, adapt, or review PopToolProject custom scripts in PowerShell, Bash, BAT, or Python, using parameter placeholders for values users choose before each run. Use for scripts intended to run as PopTool custom tools; do not apply to PopToolProject application source code or ordinary console programs.
---

# PopTool Script Authoring

Produce a complete PopToolProject custom script that collects launch-time values through the parameter dialog instead of blocking on console input.

## Select the working mode

- **Create:** Start from the user's functional requirements. Design the script and its parameter controls together; no pre-existing console script is required.
- **Adapt:** Preserve the behavior of an existing script while replacing suitable interactive input with parameter controls.
- **Review:** Find invalid, conflicting, unsafe, or unnecessarily interactive parameter handling and return a corrected complete script when requested.

## Create a script from requirements

1. Respect the requested script type. If none is specified, choose Python for portable or data-oriented logic, PowerShell for Windows administration, Bash for Unix/macOS shell workflows, and BAT only for simple Windows tasks or when explicitly requested. State the chosen type briefly.
2. Identify the values users are expected to change between runs. Turn those values into PopTool controls; keep implementation constants internal rather than exposing every literal as a parameter.
3. Choose text inputs, defaults, and closed-set choices from the user's requirements. Use `pVal` when one value appears more than once or needs a user-facing label distinct from its internal name.
4. Implement validation, error messages, exit status, and cleanup appropriate to the task. Prefer built-in language features and existing PopToolProject runtime capabilities; mention any required third-party dependency.
5. Do not add `input`, `Read-Host`, `read`, `set /p`, or another blocking prompt for values that can be collected before execution.

When useful, return a suggested tool name, short description, script type, and the complete script body. Do not invent inputs the user does not need merely to demonstrate the placeholder syntax.

## Adapt interactive input

1. Identify values obtained from users at runtime, such as Python `input()`, `Scanner`/`Scan.input`, PowerShell `Read-Host`, Bash `read`, BAT `set /p`, command-line questions, or home-grown prompt helpers.
2. Convert only values that can be supplied before execution. Preserve interaction that genuinely depends on output produced during the run, and explain why it remains interactive.
3. Replace the prompt and its read operation with the appropriate PopTool placeholder. Remove obsolete prompt text, loops, and imports only when they are no longer used.
4. Preserve parsing, validation, and business logic after the replacement. A placeholder is textual substitution performed before the interpreter sees the script; it is not a language variable or an input API.

## Choose the placeholder form

- Free text without a default: `${标题}`
- Free text with an editable default: `${标题:默认值}`
- Closed set of choices: `${标题:选项文字=实际值|选项文字=实际值}`
- Reused value or separate internal/display names:

  ```text
  pVal internalName = ${显示标题:默认值}
  ```

  Then use `${internalName}` everywhere in the executable body. `pVal internalName: ${...}` is also valid, but prefer `=` consistently. Place declarations together near the beginning; PopToolProject removes their entire lines before execution.

Use current colon syntax for new scripts. Do not generate the legacy `${名称=默认值}` form. The first choice is the default choice.

Names inside `${...}` and internal `pVal` identifiers must be nonempty and contain only Chinese characters, letters, digits, or underscores. Give controls short, user-facing labels. Do not create conflicting defaults or option sets for the same parameter ID.

## Embed values in each language

Keep string placeholders inside a string literal where the language requires one, and keep numeric or boolean conversion explicit.

```python
keyword = "${搜索关键词:Android 工具}"
count = int("${结果数量:3}")
mode = "${输出模式:摘要=summary|完整=full}"
```

```powershell
$serial = "${设备序列号}"
$count = [int]"${重试次数:3}"
$mode = "${执行模式:预览=preview|执行=run}"
```

```bash
serial="${设备序列号}"
count="${重试次数:3}"
mode="${执行模式:预览=preview|执行=run}"
```

```bat
set "serial=${设备序列号}"
set "count=${重试次数:3}"
set "mode=${执行模式:预览=preview|执行=run}"
```

When a value is used once in a command, direct placement is acceptable, for example:

```powershell
adb shell settings put system show_touches ${触摸点显示:开启=1|关闭=0}
```

## Safety and semantic limits

- Preserve the target script type and its valid quoting rules. Do not copy Python quoting into shell scripts or vice versa.
- PopToolProject performs raw textual replacement; it does not automatically escape quotes, shell metacharacters, braces, or newlines. Do not claim arbitrary untrusted input is safe merely because it is inside quotes.
- Prefer fixed choices for flags and modes. Keep existing allow-list validation for identifiers, paths, hosts, package names, or other values used in commands.
- Avoid interpolating untrusted values into a larger command string. Use the language's argument-list/process API when practical; otherwise flag the injection or quoting constraint clearly.
- Do not convert passwords, tokens, or other secrets into ordinary PopTool controls unless the user explicitly requests it: the standard controls are not secret-entry fields.
- Braces and newlines cannot be represented inside a placeholder definition. A default containing both `|` and `=` may be parsed as choices, while quotes and shell metacharacters may break the surrounding language syntax. If a requested default cannot be represented unambiguously, omit it and state the limitation.

## Verify the result

Before returning the script, check that:

- every user-adjustable launch-time value requested in the brief has an appropriate control;
- no launch-time `input`, `Read-Host`, `read`, `set /p`, or equivalent blocking prompt remains;
- every reused parameter has one `pVal` declaration and matching `${internalName}` references;
- every repeated direct placeholder has the same definition;
- choice options have nonempty, unique labels and nonempty values;
- Python placeholders representing strings are quoted before conversion or use;
- the output is the complete runnable PopToolProject script, not only a patch fragment.

Briefly list the script type and controls created, and call out any dependency, intentionally retained interactive step, or quoting/security limitation.
