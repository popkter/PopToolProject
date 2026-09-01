---
name: theme-config-should-be-json
description: User prefers theme definitions in JSON config files, not inline in ThemeConfig.qml
metadata:
  type: feedback
---

Theme palettes must be defined as JSON files under `src/poptools/ui/qml/theme/configs/<style>.json`, not hardcoded inline in `ThemeConfig.qml`.

**Why:** The user set up the `configs/` pattern (material3.json, winxp.json) specifically so theme data lives in JSON. Inlining a new theme's colors in ThemeConfig.qml was rejected as the wrong place.

**How to apply:** When adding a theme, create a `configs/<style>.json` and load it at runtime. The mario theme is wired via `SettingsController.themeConfigJson(style)` (synchronous JSON read + cache) → `Main.qml.applyThemeFromConfig()` → `ThemeConfig._applyConfig(cfg, isDark)`. Note: material3/winxp still use inline palettes in ThemeConfig.qml (their JSON files are currently unused); migrate them to the same JSON-driven path only if asked.
