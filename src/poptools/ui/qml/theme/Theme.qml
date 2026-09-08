pragma Singleton
import QtQuick

QtObject {
    property bool darkMode: false

    // The application ships one visual language with light and dark palettes.
    readonly property color primary: darkMode ? "#4090FF" : "#1677FF"
    readonly property color primaryForeground: "#FFFFFF"
    readonly property color primaryHover: darkMode ? "#66A5FF" : "#0868EA"
    readonly property color primaryContainer: darkMode ? "#16365F" : "#E8F2FF"
    readonly property color primaryContainerHover: darkMode ? "#1E477B" : "#D8E9FF"
    readonly property color primaryText: darkMode ? "#79B2FF" : "#0E6FEA"
    readonly property color secondary: darkMode ? "#AAB6C8" : "#536174"
    readonly property color secondaryForeground: "#FFFFFF"
    readonly property color secondaryHover: darkMode ? "#C3CDDB" : "#405064"
    readonly property color secondaryContainer: darkMode ? "#2A3442" : "#F1F4F8"
    readonly property color secondaryContainerHover: darkMode ? "#344152" : "#E7EBF1"
    readonly property color secondaryText: darkMode ? "#D7DEE8" : "#334155"
    readonly property color tertiary: darkMode ? "#C29BFF" : "#8556D8"
    readonly property color tertiaryForeground: "#FFFFFF"
    readonly property color tertiaryHover: darkMode ? "#D1B4FF" : "#7145BE"
    readonly property color tertiaryContainer: darkMode ? "#3B2858" : "#F1E9FF"
    readonly property color tertiaryContainerHover: darkMode ? "#4A326E" : "#E7DAFF"
    readonly property color tertiaryText: darkMode ? "#E3D2FF" : "#6F42C1"
    readonly property color surface: darkMode ? "#11161E" : "#F8FAFC"
    readonly property color sidebar: darkMode ? "#171D26" : "#F4F6F8"
    readonly property color navigationSelected: darkMode ? "#16365F" : "#DCEAFF"
    readonly property color surfaceContainerLow: darkMode ? "#171E28" : "#FFFFFF"
    readonly property color surfaceContainer: darkMode ? "#1D2530" : "#F5F7FA"
    readonly property color surfaceContainerHigh: darkMode ? "#26313F" : "#EDF1F5"
    readonly property color outline: darkMode ? "#435064" : "#D6DEE8"
    readonly property color outlineVariant: darkMode ? "#303B4B" : "#E4E9F0"
    readonly property color popupSurface: darkMode ? "#1B232E" : "#FFFFFF"
    readonly property color popupHover: darkMode ? "#26313F" : "#F4F6F9"
    readonly property color popupSelected: darkMode ? "#173A66" : "#E8F2FF"
    readonly property color popupShadow: darkMode ? "#99000000" : "#290F172A"
    readonly property color dialogShadow: darkMode ? "#B3000000" : "#380F172A"
    readonly property color scrim: darkMode ? "#8F070B12" : "#470F172A"
    readonly property color textPrimary: darkMode ? "#F3F6FA" : "#101722"
    readonly property color textSecondary: darkMode ? "#93A0B3" : "#7C899B"
    readonly property color success: darkMode ? "#5FD49A" : "#29AF6F"
    readonly property color successForeground: darkMode ? "#071D13" : "#FFFFFF"
    readonly property color successContainer: darkMode ? "#123D2A" : "#E8F8EF"
    readonly property color tealContainer: darkMode ? "#123A3B" : "#E8F8F7"
    readonly property color teal: darkMode ? "#63D7D2" : "#159B95"
    readonly property color errorColor: darkMode ? "#FF8D87" : "#E5484D"
    readonly property color errorContainer: darkMode ? "#4C2225" : "#FFF0F0"
    readonly property color middlePanel: surfaceContainerLow
    readonly property color consoleBackground: "#10151D"
    readonly property color consoleText: "#E5E7EB"
    readonly property color consoleMuted: "#728298"
    readonly property color consoleHeaderBackground: "#252C36"
    readonly property color consoleTag: "#66AFFF"
    readonly property color consoleWarning: "#FFCE66"
    readonly property color consoleError: "#FF8585"
    readonly property color consoleDivider: outlineVariant

    property int fontDisplay: 40
    property int fontPageTitle: 30
    property int fontTitleLarge: 22
    property int fontDialogTitle: 22
    property int fontSectionTitle: 18
    property int fontComponentTitle: 15
    property int fontButton: 14
    property int fontBody: 14
    property int fontLabel: 13
    property int fontSupporting: 13
    property int fontCode: 13
    property int fontCaption: 12
    property int fontMicro: 10
    property int radiusNone: 0
    property int radiusTiny: 4
    property int radiusSmall: 7
    property int radiusMedium: 10
    property int radiusLarge: 16
    property int radiusXLarge: 20
    property int radiusFull: 9999
    readonly property int applicationRadius: 10
    property int space0: 0
    property int space4: 4
    property int space8: 8
    property int space12: 12
    property int space16: 16
    property int space20: 20
    property int space24: 24
    property int space28: 28
    property int space32: 32
    property int space36: 36
    property int space40: 40
    property int pagePadding: 24
    property int pagePaddingCompact: 14
    property int panelPadding: 16
    property int panelPaddingCompact: 10
    property int sectionSpacing: 16
    property int controlSpacing: 8
    property int terminalContentPadding: 20
    readonly property int primaryNavigationWidth: 246
    property int navigationMaximumWidth: 306
    property int borderWidthThin: 1
    property int borderWidthMedium: 2
    property int borderWidthThick: 3
    readonly property color buttonDefault: primary
    readonly property color buttonHover: primaryHover
    readonly property color buttonPressed: darkMode ? "#2578E8" : "#005AC7"
    readonly property color buttonDisabled: surfaceContainerHigh
    readonly property color inputDefault: surfaceContainerLow
    readonly property color inputHover: surfaceContainer
    readonly property color inputFocused: primaryContainer
    readonly property color inputError: errorColor
    readonly property color inputDisabled: surfaceContainer
    readonly property color cardDefault: surfaceContainerLow
    readonly property color cardHover: surfaceContainer
    readonly property color cardSelected: primaryContainer
    readonly property color cardDisabled: surfaceContainerHigh
    readonly property color borderColorDefault: outline
    readonly property color borderColorHover: primary
    readonly property color borderColorFocused: primary
    readonly property color borderColorError: errorColor
    readonly property color buttonShadow: primaryHover
    readonly property color buttonHighlight: "transparent"
    property int unit: 8
}
