pragma Singleton
import QtQuick

QtObject {
    property bool darkMode: false
    readonly property color primary: darkMode ? "#C5C0FF" : "#4543C7"
    readonly property color primaryForeground: darkMode ? "#1D1B20" : "#FFFFFF"
    readonly property color primaryHover: darkMode ? "#D8D4FF" : "#3734B4"
    readonly property color primaryContainer: darkMode ? "#34316E" : "#E7E4FF"
    readonly property color primaryContainerHover: darkMode ? "#423F80" : "#DBD7FF"
    readonly property color primaryText: darkMode ? "#E7E4FF" : "#34319E"
    readonly property color surface: darkMode ? "#211F26" : "#FCF9FF"
    readonly property color surfaceContainerLow: darkMode ? "#1D1B20" : "#F8F5FC"
    readonly property color surfaceContainer: darkMode ? "#211F26" : "#F2EFF8"
    readonly property color surfaceContainerHigh: darkMode ? "#2B2930" : "#ECE8F3"
    readonly property color outline: darkMode ? "#938F99" : "#C9C5CF"
    readonly property color outlineVariant: darkMode ? "#49454F" : "#E2DEE7"
    readonly property color textPrimary: darkMode ? "#E6E1E9" : "#1D1B20"
    readonly property color textSecondary: darkMode ? "#CAC4D0" : "#67636C"
    readonly property color success: darkMode ? "#7DDBA4" : "#16844C"
    readonly property color successForeground: darkMode ? "#082016" : "#FFFFFF"
    readonly property color successContainer: darkMode ? "#0B4B2B" : "#D9F8E4"
    readonly property color tealContainer: darkMode ? "#174B48" : "#D8F2EF"
    readonly property color teal: darkMode ? "#9BD5D0" : "#1E6F69"
    readonly property color errorColor: darkMode ? "#FFB4AB" : "#B3261E"
    readonly property color errorContainer: darkMode ? "#690005" : "#F9DEDC"
    readonly property color middlePanel: darkMode ? "#18242D" : "#EEF7FF"
    readonly property color consoleBackground: darkMode ? "#141A20" : "#EEF3F8"
    readonly property color consoleText: darkMode ? "#E8EEF5" : "#1B2430"
    readonly property color consoleMuted: darkMode ? "#A9C7D8" : "#536779"
    readonly property color consoleHeaderBackground: darkMode ? "#202A33" : "#E8EEF3"
    readonly property color consoleTag: darkMode ? "#A8D8FF" : "#075985"
    readonly property color consoleWarning: darkMode ? "#FFD166" : "#9A6700"
    readonly property color consoleError: darkMode ? "#FF9B93" : "#B42318"
    readonly property color consoleDivider: darkMode ? "#ba0101" : "#e80000"

    // Shared desktop typography scale. Components should use these semantic
    // roles instead of introducing local pixel sizes.
    readonly property int fontDisplay: 40
    readonly property int fontPageTitle: 30
    readonly property int fontTitleLarge: 24
    readonly property int fontDialogTitle: 22
    readonly property int fontSectionTitle: 20
    readonly property int fontComponentTitle: 16
    readonly property int fontButton: 16
    readonly property int fontBody: 14
    readonly property int fontLabel: 13
    readonly property int fontSupporting: 13
    readonly property int fontCode: 13
    readonly property int fontCaption: 12
    readonly property int fontMicro: 10

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int unit: 8
}



