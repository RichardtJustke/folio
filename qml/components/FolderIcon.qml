import QtQuick
import Folio

// Pasta no estilo de ícones escolhido; pastas XDG (Downloads, Documentos...) levam o símbolo delas
Item {
    id: root
    property string glyph // ícone simbólico da pasta (Downloads, Documentos...)

    readonly property string style: Settings.fileIcons
    readonly property bool system: style === "system"
    // duotone/contorno: o símbolo da pasta XDG substitui o desenho da pasta
    readonly property bool glyphOnly: glyph !== "" && (style === "duotone" || style === "outline")

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        smooth: true
        source: root.system ? Theme.icon((root.glyph ? root.glyph.replace("-symbolic", "") + "," : "") + "folder", undefined) + "&pack=0"
              : Theme.fileIcon("folder", "", root.glyphOnly)
    }
    Image {
        visible: root.glyph !== "" && !root.system && !(root.style === "outline" && !root.glyphOnly)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.glyphOnly ? (root.height - height) / 2 : root.height * 0.47
        width: root.width * (root.glyphOnly ? 0.5 : 0.3); height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.glyph ? Theme.icon(root.glyph, root.glyphOnly ? Qt.lighter(Settings.accent, Theme.light ? 1.0 : 1.35)
                                                                    : Qt.darker(Settings.accent, 1.6)) : ""
        opacity: root.glyphOnly ? 1 : 0.8
    }
}
