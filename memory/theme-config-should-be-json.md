---
name: theme-config-should-be-json
description: User prefers theme definitions in JSON config files, not inline in ThemeConfig.qml
metadata:
  type: feedback
---

Theme palettes must be defined as JSON files under `src/poptools/ui/qml/theme/configs/<style>.json`, not hardcoded inline in `ThemeConfig.qml`.

**Why:** The `configs/` pattern keeps theme data separate from the generic QML theme applicator and from business settings.

**How to apply:** Add `configs/<style>.json` with a name, complete `colors`, `darkColors`, and `radius` sections. `ThemeCatalog` scans and validates the directory at startup and whenever settings opens. `SettingsController.themeConfigJson(style)` exposes only validated JSON, `Main.qml.applyThemeFromConfig()` selects light or dark mode, and `ThemeConfig.applyTheme()` writes the shared `Theme` tokens. Material 3 is the fallback when a saved theme is unavailable. Current packaged themes are Material 3, Windows XP, and Mario.
