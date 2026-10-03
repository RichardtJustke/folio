pragma Singleton
import QtQuick

QtObject {
    // superfícies translúcidas: o blur do Hyprland aparece por trás
    readonly property color windowBg: Qt.rgba(0.10, 0.10, 0.11, 0.62)
    readonly property color sidebarBg: Qt.rgba(1, 1, 1, 0.045)
    readonly property color border: Qt.rgba(1, 1, 1, 0.09)
    readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.14)
    readonly property color pillBg: Qt.rgba(1, 1, 1, 0.07)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color selected: Qt.rgba(1, 1, 1, 0.10)
    readonly property color menuBg: Qt.rgba(0.17, 0.17, 0.18, 0.97)

    readonly property color text: "#ececec"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color textFaint: Qt.rgba(1, 1, 1, 0.32)
    readonly property color accent: "#0a84ff"
    readonly property color accentSoft: "#2f86f0"
    readonly property color info: "#4aa3ff"
    readonly property color sidebarIcon: "#3d9bff"
    readonly property color danger: "#ff6961"

    readonly property color close: "#ff5f57"
    readonly property color minimize: "#febc2e"
    readonly property color zoom: "#28c840"
    readonly property color lightInactive: Qt.rgba(1, 1, 1, 0.18)

    readonly property int radius: 14
    readonly property int sidebarWidth: 210
    readonly property int headerHeight: 54
    readonly property int tileWidth: 116
    readonly property int tileHeight: 138
    readonly property int iconSize: 76
    readonly property int fontSize: 13
    readonly property int listRowHeight: 28
    readonly property int sectionHeaderHeight: 40
    readonly property string folderSvg: "qrc:/qt/qml/Folio/assets/folder.svg"

    function sizeLabel(bytes) {
        const units = ["bytes", "KB", "MB", "GB", "TB"]
        let i = 0, v = bytes
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++ }
        return (i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)) + " " + units[i]
    }

    function itemsLabel(n) {
        return n < 0 ? "—" : n === 1 ? "1 item" : n + " itens"
    }

    function dateLabel(d) {
        if (!d) return ""
        const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const diff = Math.round((today - day) / 86400000)
        const time = Qt.formatTime(d, "HH:mm")
        if (diff === 0) return "Hoje, " + time
        if (diff === 1) return "Ontem, " + time
        return Qt.formatDateTime(d, "dd/MM/yyyy HH:mm")
    }

    // URL de ícone do tema, opcionalmente tingido (sem "#", que viraria fragmento da URL)
    function icon(names, tint) {
        return "image://icon/" + names + (tint ? "?color=" + tint.toString().slice(1) : "")
    }
}
