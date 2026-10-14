pragma Singleton
import QtQuick

QtObject {
    readonly property bool light: Settings.theme === "light"
    readonly property real base: light ? 0 : 1 // canal das sobreposições (preto no tema claro)
    function overlay(alpha) { return Qt.rgba(base, base, base, alpha) }
    function tint(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }

    // superfícies translúcidas: o blur do Hyprland aparece por trás
    readonly property color windowBg: light ? Qt.rgba(0.97, 0.97, 0.98, Math.min(1, Settings.backgroundOpacity + 0.25))
                                            : Qt.rgba(0.10, 0.10, 0.11, Settings.backgroundOpacity)
    readonly property color sidebarBg: overlay(light ? 0.035 : 0.045)
    readonly property color border: overlay(light ? 0.10 : 0.09)
    readonly property color borderStrong: overlay(0.14)
    readonly property color pillBg: overlay(light ? 0.055 : 0.07)
    readonly property color hover: overlay(light ? 0.05 : 0.06)
    readonly property color selected: overlay(light ? 0.09 : 0.10)
    readonly property color subtle: overlay(light ? 0.025 : 0.03)
    readonly property color buttonBg: overlay(light ? 0.07 : 0.09)
    readonly property color buttonHover: overlay(light ? 0.11 : 0.14)
    // menus e diálogos também são vidro: seguem a transparência da janela (com piso para continuar legível)
    readonly property real menuAlpha: Math.max(0.5, Math.min(0.97, Settings.backgroundOpacity + 0.12 + (Settings.legibility ? 0.08 : 0)))
    readonly property color menuBg: light ? Qt.rgba(0.98, 0.98, 0.99, menuAlpha) : Qt.rgba(0.17, 0.17, 0.18, menuAlpha)

    readonly property color text: light ? "#1d1d1f" : "#ececec"
    // com "legibilidade", textos secundários ganham contraste para não sumirem no vidro
    readonly property color textDim: overlay(Settings.legibility ? (light ? 0.76 : 0.74) : (light ? 0.62 : 0.55))
    readonly property color textFaint: overlay(Settings.legibility ? (light ? 0.55 : 0.52) : (light ? 0.40 : 0.32))
    // painel atrás da área de arquivos: devolve fundo sólido onde se lê
    readonly property color contentBacking: !Settings.legibility ? "transparent"
        : light ? Qt.rgba(1, 1, 1, 0.55 * (1.05 - Settings.backgroundOpacity))
                : Qt.rgba(0, 0, 0, 0.45 * (1.05 - Settings.backgroundOpacity))
    readonly property color accent: Settings.accent
    readonly property color accentSoft: Qt.lighter(Settings.accent, 1.1)
    readonly property color accentGlow: tint(Settings.accent, 0.25)
    readonly property color info: Qt.lighter(Settings.accent, 1.25)
    readonly property color sidebarIcon: Qt.lighter(Settings.accent, light ? 1.0 : 1.2)
    readonly property color danger: "#ff6961"
    readonly property color accentText: "white"

    readonly property int radius: Settings.cornerRadius
    readonly property int sidebarWidth: 210
    readonly property int sidebarCompactWidth: 56
    readonly property int headerHeight: 54
    readonly property int iconSize: Settings.iconSize
    readonly property int tileWidth: iconSize + 40
    readonly property int tileHeight: iconSize + 62
    readonly property int fontSize: Settings.fontSize
    readonly property int listRowHeight: fontSize + 15
    readonly property int sectionHeaderHeight: 40
    readonly property string folderSvg: "qrc:/qt/qml/Folio/assets/folder.svg"

    // animações: duração em ms já ajustada à velocidade escolhida; 0 com "reduzir movimento"
    readonly property bool motion: !Settings.reduceMotion
    function dur(ms) { return Settings.reduceMotion ? 0 : Math.round(ms / Settings.animationSpeed) }

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
    // ícones da área de arquivos no estilo escolhido (Configurações → Ícones dos arquivos)
    function fileIcon(names, fileName, tileOnly) {
        const dot = fileName ? fileName.lastIndexOf(".") : -1
        const ext = dot > 0 ? fileName.slice(dot + 1) : ""
        return "image://fileicon/" + Settings.fileIcons + "/" + names + "?ext=" + encodeURIComponent(ext)
            + "&accent=" + Settings.accent.slice(1) + "&light=" + (light ? 1 : 0) + (tileOnly ? "&tile=1" : "")
    }

    function icon(names, tint) {
        return "image://icon/" + names + "?rev=" + Settings.iconRevision + (tint ? "&color=" + tint.toString().slice(1) : "")
    }
}
