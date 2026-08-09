pragma Singleton
import QtQuick

QtObject {
    property string currentTheme: "material3"

    function applyTheme(themeName, isDark, configObj) {
        if (!configObj)
            return false
        var palette = isDark ? configObj.darkColors : configObj.colors
        if (!palette || !configObj.radius)
            return false

        // SettingsController exposes only fully validated configurations, so
        // applying a theme cannot assign undefined values to Theme properties.
        _applyPalette(palette)
        _applyRadius(configObj.radius)
        _applyDerived(palette)
        currentTheme = themeName
        return true
    }

    function _applyPalette(p) {
        Theme.primary = p.primary
        Theme.primaryForeground = p.primaryForeground
        Theme.primaryHover = p.primaryHover
        Theme.primaryContainer = p.primaryContainer
        Theme.primaryContainerHover = p.primaryContainerHover
        Theme.primaryText = p.primaryText
        Theme.secondary = p.secondary || p.primary
        Theme.secondaryForeground = p.secondaryForeground || p.primaryForeground
        Theme.secondaryHover = p.secondaryHover || p.primaryHover
        Theme.secondaryContainer = p.secondaryContainer || p.primaryContainer
        Theme.secondaryContainerHover = p.secondaryContainerHover || p.primaryContainerHover
        Theme.secondaryText = p.secondaryText || p.primaryText
        Theme.tertiary = p.tertiary || p.secondary || p.primary
        Theme.tertiaryForeground = p.tertiaryForeground || p.secondaryForeground || p.primaryForeground
        Theme.tertiaryHover = p.tertiaryHover || p.secondaryHover || p.primaryHover
        Theme.tertiaryContainer = p.tertiaryContainer || p.secondaryContainer || p.primaryContainer
        Theme.tertiaryContainerHover = p.tertiaryContainerHover || p.secondaryContainerHover || p.primaryContainerHover
        Theme.tertiaryText = p.tertiaryText || p.secondaryText || p.primaryText
        Theme.surface = p.surface
        Theme.surfaceContainerLow = p.surfaceContainerLow
        Theme.surfaceContainer = p.surfaceContainer
        Theme.surfaceContainerHigh = p.surfaceContainerHigh
        Theme.outline = p.outline
        Theme.outlineVariant = p.outlineVariant
        Theme.textPrimary = p.textPrimary
        Theme.textSecondary = p.textSecondary
        Theme.success = p.success
        Theme.successForeground = p.successForeground
        Theme.successContainer = p.successContainer
        Theme.tealContainer = p.tealContainer
        Theme.teal = p.teal
        Theme.errorColor = p.errorColor
        Theme.errorContainer = p.errorContainer
        Theme.middlePanel = p.middlePanel
        Theme.consoleBackground = p.consoleBackground
        Theme.consoleText = p.consoleText
        Theme.consoleMuted = p.consoleMuted
        Theme.consoleHeaderBackground = p.consoleHeaderBackground
        Theme.consoleTag = p.consoleTag
        Theme.consoleWarning = p.consoleWarning
        Theme.consoleError = p.consoleError
        Theme.consoleDivider = p.consoleDivider
    }

    function _applyRadius(r) {
        Theme.radiusNone = r.none
        Theme.radiusTiny = r.tiny
        Theme.radiusSmall = r.small
        Theme.radiusMedium = r.medium
        Theme.radiusLarge = r.large
        Theme.radiusXLarge = r.xlarge
        Theme.radiusFull = r.full
    }

    function _applyDerived(p) {
        // Button states
        Theme.buttonDefault = p.buttonDefault
        Theme.buttonHover = p.buttonHover
        Theme.buttonPressed = p.buttonPressed
        Theme.buttonDisabled = p.buttonDisabled
        Theme.buttonShadow = p.buttonShadow
        Theme.buttonHighlight = p.buttonHighlight

        // Input states
        Theme.inputDefault = p.surface
        Theme.inputHover = p.surfaceContainer
        Theme.inputFocused = p.primaryContainer
        Theme.inputError = p.errorColor
        Theme.inputDisabled = p.surfaceContainerLow

        // Card states
        Theme.cardDefault = p.surfaceContainerLow
        Theme.cardHover = p.surfaceContainer
        Theme.cardSelected = p.cardSelected || p.primaryContainer
        Theme.cardDisabled = p.surfaceContainerHigh

        // Border states
        Theme.borderColorDefault = p.outline
        Theme.borderColorHover = p.primary
        Theme.borderColorFocused = p.primary
        Theme.borderColorError = p.errorColor
    }
}
