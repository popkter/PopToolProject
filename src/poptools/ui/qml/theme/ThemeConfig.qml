pragma Singleton
import QtQuick

QtObject {
    property string currentTheme: "material3"

    // ---- Material 3 palettes ----
    readonly property var m3Light: ({
        primary: "#4543C7", primaryForeground: "#FFFFFF", primaryHover: "#3734B4",
        primaryContainer: "#E7E4FF", primaryContainerHover: "#DBD7FF", primaryText: "#34319E",
        surface: "#FCF9FF", surfaceContainerLow: "#F8F5FC", surfaceContainer: "#F2EFF8",
        surfaceContainerHigh: "#ECE8F3", outline: "#C9C5CF", outlineVariant: "#E2DEE7",
        textPrimary: "#1D1B20", textSecondary: "#67636C",
        success: "#16844C", successForeground: "#FFFFFF", successContainer: "#D9F8E4",
        tealContainer: "#D8F2EF", teal: "#1E6F69",
        errorColor: "#B3261E", errorContainer: "#F9DEDC",
        middlePanel: "#EEF7FF",
        consoleBackground: "#EEF3F8", consoleText: "#1B2430", consoleMuted: "#536779",
        consoleHeaderBackground: "#E8EEF3", consoleTag: "#075985",
        consoleWarning: "#9A6700", consoleError: "#B42318", consoleDivider: "#e80000",
        buttonDefault: "#4543C7", buttonHover: "#3734B4", buttonPressed: "#2823A0",
        buttonDisabled: "#ECE8F3", buttonShadow: "#C9C5CF", buttonHighlight: "#FFFFFF"
    })

    readonly property var m3Dark: ({
        primary: "#C5C0FF", primaryForeground: "#1D1B20", primaryHover: "#D8D4FF",
        primaryContainer: "#34316E", primaryContainerHover: "#423F80", primaryText: "#E7E4FF",
        surface: "#211F26", surfaceContainerLow: "#1D1B20", surfaceContainer: "#211F26",
        surfaceContainerHigh: "#2B2930", outline: "#938F99", outlineVariant: "#49454F",
        textPrimary: "#E6E1E9", textSecondary: "#CAC4D0",
        success: "#7DDBA4", successForeground: "#082016", successContainer: "#0B4B2B",
        tealContainer: "#174B48", teal: "#9BD5D0",
        errorColor: "#FFB4AB", errorContainer: "#690005",
        middlePanel: "#18242D",
        consoleBackground: "#141A20", consoleText: "#E8EEF5", consoleMuted: "#A9C7D8",
        consoleHeaderBackground: "#202A33", consoleTag: "#A8D8FF",
        consoleWarning: "#FFD166", consoleError: "#FF9B93", consoleDivider: "#ba0101",
        buttonDefault: "#C5C0FF", buttonHover: "#D8D4FF", buttonPressed: "#9D8FFF",
        buttonDisabled: "#2B2930", buttonShadow: "#938F99", buttonHighlight: "#FFFFFF"
    })

    // ---- Windows XP palettes ----
    readonly property var xpLight: ({
        primary: "#0054E3", primaryForeground: "#FFFFFF", primaryHover: "#276AC6",
        primaryContainer: "#D4E4F7", primaryContainerHover: "#C2D8EE", primaryText: "#003399",
        surface: "#ECE9D8", surfaceContainerLow: "#F5F3E8", surfaceContainer: "#EFECD9",
        surfaceContainerHigh: "#E0DBC7", outline: "#808080", outlineVariant: "#A0A0A0",
        textPrimary: "#000000", textSecondary: "#444444",
        success: "#008000", successForeground: "#FFFFFF", successContainer: "#C8E6C9",
        tealContainer: "#B2DFDB", teal: "#00695C",
        errorColor: "#D32F2F", errorContainer: "#FFCDD2",
        middlePanel: "#D4E4F7",
        consoleBackground: "#000000", consoleText: "#00FF00", consoleMuted: "#808080",
        consoleHeaderBackground: "#0A246A", consoleTag: "#4FC3F7",
        consoleWarning: "#FFC107", consoleError: "#FF5252", consoleDivider: "#FF0000",
        buttonDefault: "#F0F0F0", buttonHover: "#E8E8E8", buttonPressed: "#D0D0D0",
        buttonDisabled: "#C8C8C8", buttonShadow: "#808080", buttonHighlight: "#FFFFFF",
        cardSelected: "#B8CCE4"
    })

    readonly property var xpDark: ({
        primary: "#4D8ED6", primaryForeground: "#FFFFFF", primaryHover: "#6BA3E0",
        primaryContainer: "#1E3A5F", primaryContainerHover: "#2A4A73", primaryText: "#8CB8FF",
        surface: "#1A1A1A", surfaceContainerLow: "#252525", surfaceContainer: "#2D2D2D",
        surfaceContainerHigh: "#383838", outline: "#606060", outlineVariant: "#505050",
        textPrimary: "#E0E0E0", textSecondary: "#A0A0A0",
        success: "#4CAF50", successForeground: "#FFFFFF", successContainer: "#1B5E20",
        tealContainer: "#004D40", teal: "#80CBC4",
        errorColor: "#EF5350", errorContainer: "#B71C1C",
        middlePanel: "#1E3A5F",
        consoleBackground: "#0D0D0D", consoleText: "#00FF00", consoleMuted: "#606060",
        consoleHeaderBackground: "#0A1A2A", consoleTag: "#29B6F6",
        consoleWarning: "#FFCA28", consoleError: "#FF5252", consoleDivider: "#FF0000",
        buttonDefault: "#3A3A3A", buttonHover: "#484848", buttonPressed: "#2A2A2A",
        buttonDisabled: "#252525", buttonShadow: "#000000", buttonHighlight: "#606060"
    })

    // XP uses small radii; M3 uses larger ones.
    readonly property var m3Radius: ({ none: 0, tiny: 4, small: 8, medium: 12, large: 18, xlarge: 24, full: 9999 })
    readonly property var xpRadius: ({ none: 0, tiny: 1, small: 2, medium: 4, large: 6, xlarge: 8, full: 9999 })

    function applyTheme(themeName, isDark) {
        currentTheme = themeName
        var palette, radius

        if (themeName === "winxp") {
            palette = isDark ? xpDark : xpLight
            radius = xpRadius
        } else {
            palette = isDark ? m3Dark : m3Light
            radius = m3Radius
        }

        _applyPalette(palette)
        _applyRadius(radius)
        _applyDerived(palette)
    }

    function _applyPalette(p) {
        Theme.primary = p.primary
        Theme.primaryForeground = p.primaryForeground
        Theme.primaryHover = p.primaryHover
        Theme.primaryContainer = p.primaryContainer
        Theme.primaryContainerHover = p.primaryContainerHover
        Theme.primaryText = p.primaryText
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
