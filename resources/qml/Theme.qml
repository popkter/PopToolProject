pragma Singleton
import QtQuick
QtObject {
    readonly property color background: Settings.dark ? "#171b23" : "#f7f8fa"
    readonly property color surface: Settings.dark ? "#222833" : "#ffffff"
    readonly property color field: Settings.dark ? "#2b313d" : "#f5f7fa"
    readonly property color border: Settings.dark ? "#363e4b" : "#e5e7eb"
    readonly property color text: Settings.dark ? "#eef1f6" : "#111827"
    readonly property color muted: Settings.dark ? "#a1abba" : "#808896"
    readonly property color accent: Settings.accent
    readonly property color selected: Settings.dark ? "#233d58" : "#eef6ff"
}
