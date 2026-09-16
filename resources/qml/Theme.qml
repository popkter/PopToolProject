pragma Singleton
import QtQuick
QtObject {
    readonly property int captionHeight: 42
    readonly property int captionButtonWidth: 46
    readonly property int captionControlsWidth: captionButtonWidth * 3
    readonly property int dialogRadius: 10
    readonly property int popupRadius: 6
    readonly property color danger: Settings.dark ? "#ff9b9b" : "#bd3434"
    readonly property color dangerSurface: Settings.dark ? "#542d35" : "#ffcccc"
    readonly property color background: Settings.dark ? "#171b23" : "#f7f8fa"
    readonly property color surface: Settings.dark ? "#222833" : "#ffffff"
    readonly property color field: Settings.dark ? "#2b313d" : "#f5f7fa"
    readonly property color border: Settings.dark ? "#363e4b" : "#e5e7eb"
    readonly property color text: Settings.dark ? "#eef1f6" : "#111827"
    readonly property color muted: Settings.dark ? "#a1abba" : "#808896"
    readonly property color accent: Settings.accent
    readonly property color selected: Settings.dark ? "#233d58" : "#eef6ff"
}
