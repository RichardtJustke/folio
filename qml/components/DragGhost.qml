import QtQuick
import Folio

// Imagem que segue o cursor ao arrastar: até 3 ícones empilhados e, com 2 ou mais itens,
// a quantidade discreta no canto. Fica fora da vista; render() a captura para o Drag.
Item {
    id: root

    property var entries: [] // o item arrastado primeiro
    property int count: 0

    width: 92; height: 86
    x: -width - 400 // fora da vista (grabToImage precisa do item visível na cena)

    function render(first, all, total, done) {
        const rest = all.filter(e => e.path !== first.path)
        entries = [first].concat(rest).slice(0, 3)
        count = total
        grabToImage(r => done(r.url))
    }

    component Tile: Item { // o ícone como a grade o desenha (o estilo já traz o fundo)
        id: tile
        property var entry: ({})
        width: 58; height: 58
        Rectangle { // fundo sólido: os ícones duotone são translúcidos e se misturariam na pilha
            visible: Settings.fileIcons === "duotone"
            anchors.fill: parent
            anchors.margins: tile.entry.isDir === true ? 0 : 4
            radius: width * 0.24
            color: Theme.light ? "#f4f4f6" : "#2c2c2f"
        }
        FolderIcon {
            visible: tile.entry.isDir === true
            anchors.fill: parent
            glyph: tile.entry.glyph || ""
        }
        Image {
            visible: tile.entry.isDir !== true
            anchors.fill: parent
            anchors.margins: 4
            sourceSize: Qt.size(116, 116)
            source: tile.entry.icon && tile.entry.isDir !== true
                    ? Settings.fileIcons === "system" ? Theme.icon(tile.entry.icon) + "&pack=0" : Theme.fileIcon(tile.entry.icon, tile.entry.name)
                    : ""
        }
    }

    // de trás para a frente: os de trás giram e se afastam um pouco
    Repeater {
        model: root.entries.length
        delegate: Tile {
            required property int index
            readonly property int depth: root.entries.length - 1 - index // 0 = frente
            entry: root.entries[depth]
            x: 6 + depth * 9
            y: 14 - depth * 6
            z: -depth
            rotation: depth * 6
            opacity: depth === 0 ? 1 : depth === 1 ? 0.9 : 0.75
        }
    }

    Rectangle { // quantidade: discreta, no canto de baixo do ícone da frente
        visible: root.count >= 2
        x: 6 + 58 - width - 4
        y: 14 + 58 - height - 4
        z: 10
        width: Math.max(16, countText.implicitWidth + 8); height: 16; radius: 5
        color: Qt.rgba(0, 0, 0, 0.42)
        Text {
            id: countText
            anchors.centerIn: parent
            text: root.count
            color: Qt.rgba(1, 1, 1, 0.9)
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }
}
