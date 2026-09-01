pragma Singleton
import QtQuick

QtObject {
    property bool darkMode: false

    // Theme colors — defaults are Material 3; ThemeConfig overrides at runtime.
    property color primary: darkMode ? "#C5C0FF" : "#4543C7"
    property color primaryForeground: darkMode ? "#1D1B20" : "#FFFFFF"
    property color primaryHover: darkMode ? "#D8D4FF" : "#3734B4"
    property color primaryContainer: darkMode ? "#34316E" : "#E7E4FF"
    property color primaryContainerHover: darkMode ? "#423F80" : "#DBD7FF"
    property color primaryText: darkMode ? "#E7E4FF" : "#34319E"
    property color surface: darkMode ? "#211F26" : "#FCF9FF"
    property color surfaceContainerLow: darkMode ? "#1D1B20" : "#F8F5FC"
    property color surfaceContainer: darkMode ? "#211F26" : "#F2EFF8"
    property color surfaceContainerHigh: darkMode ? "#2B2930" : "#ECE8F3"
    property color outline: darkMode ? "#938F99" : "#C9C5CF"
    property color outlineVariant: darkMode ? "#49454F" : "#E2DEE7"
    property color textPrimary: darkMode ? "#E6E1E9" : "#1D1B20"
    property color textSecondary: darkMode ? "#CAC4D0" : "#67636C"
    property color success: darkMode ? "#7DDBA4" : "#16844C"
    property color successForeground: darkMode ? "#082016" : "#FFFFFF"
    property color successContainer: darkMode ? "#0B4B2B" : "#D9F8E4"
    property color tealContainer: darkMode ? "#174B48" : "#D8F2EF"
    property color teal: darkMode ? "#9BD5D0" : "#1E6F69"
    property color errorColor: darkMode ? "#FFB4AB" : "#B3261E"
    property color errorContainer: darkMode ? "#690005" : "#F9DEDC"
    property color middlePanel: darkMode ? "#18242D" : "#EEF7FF"
    property color consoleBackground: darkMode ? "#141A20" : "#EEF3F8"
    property color consoleText: darkMode ? "#E8EEF5" : "#1B2430"
    property color consoleMuted: darkMode ? "#A9C7D8" : "#536779"
    property color consoleHeaderBackground: darkMode ? "#202A33" : "#E8EEF3"
    property color consoleTag: darkMode ? "#A8D8FF" : "#075985"
    property color consoleWarning: darkMode ? "#FFD166" : "#9A6700"
    property color consoleError: darkMode ? "#FF9B93" : "#B42318"
    property color consoleDivider: darkMode ? "#ba0101" : "#e80000"

    // Shared desktop typography scale. Components should use these semantic
    // roles instead of introducing local pixel sizes.
    property int fontDisplay: 40
    property int fontPageTitle: 30
    property int fontTitleLarge: 24
    property int fontDialogTitle: 22
    property int fontSectionTitle: 20
    property int fontComponentTitle: 16
    property int fontButton: 16
    property int fontBody: 14
    property int fontLabel: 13
    property int fontSupporting: 13
    property int fontCode: 13
    property int fontCaption: 12
    property int fontMicro: 10

    property int radiusSmall: 8
    property int radiusMedium: 12
    property int radiusLarge: 18

    // Extended radius values for more granular control
    property int radiusNone: 0
    property int radiusTiny: 4
    property int radiusXLarge: 24
    property int radiusFull: 9999

    // Border widths
    property int borderWidthThin: 1
    property int borderWidthMedium: 2
    property int borderWidthThick: 3

    // Button state colors
    property color buttonDefault: primary
    property color buttonHover: primaryHover
    property color buttonPressed: darkMode ? "#9D8FFF" : "#2823A0"
    property color buttonDisabled: surfaceContainerHigh

    // Input state colors
    property color inputDefault: surface
    property color inputHover: surfaceContainer
    property color inputFocused: primaryContainer
    property color inputError: errorColor
    property color inputDisabled: surfaceContainerLow

    // Card state colors
    property color cardDefault: surfaceContainerLow
    property color cardHover: surfaceContainer
    property color cardSelected: primaryContainer
    property color cardDisabled: surfaceContainerHigh

    // Border state colors
    property color borderColorDefault: outline
    property color borderColorHover: primary
    property color borderColorFocused: primary
    property color borderColorError: errorColor

    // XP-specific 3D bevel colors (used by components for raised/sunken effects)
    property color buttonShadow: outline
    property color buttonHighlight: "#FFFFFF"

    property int unit: 8
}
