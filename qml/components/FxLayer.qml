import QtQuick
import Folio

// Camada de efeitos sobre a janela (não recebe cliques): itens voando, encolhendo e partículas.
Item {
    id: root

    anchors.fill: parent
    enabled: false

    // items: [{ entry, x, y, size }] com o centro de cada item em coordenadas da janela
    function fly(items, tx, ty, done) {
        if (!Theme.motion) { if (done) done(); return }
        const n = Math.min(items.length, 8)
        for (let i = 0; i < n; i++) {
            const g = ghost.createObject(root, {
                entry: items[i].entry, fromX: items[i].x, fromY: items[i].y, size: items[i].size,
                toX: tx, toY: ty, delay: i * 45, flying: true
            })
            if (i === n - 1 && done) g.arrived.connect(done)
        }
    }

    function shrink(items) {
        if (!Theme.motion) return
        const n = Math.min(items.length, 16)
        for (let i = 0; i < n; i++)
            ghost.createObject(root, {
                entry: items[i].entry, fromX: items[i].x, fromY: items[i].y, size: items[i].size,
                toX: items[i].x, toY: items[i].y, flying: false
            })
    }

    // partículas (esvaziar a Lixeira)
    function burst(x, y) {
        if (!Theme.motion) return
        for (let i = 0; i < 14; i++) {
            const a = (Math.random() * 1.6 - 0.8) - Math.PI / 2
            const d = 40 + Math.random() * 60
            particle.createObject(root, { x: x, y: y, startX: x, startY: y, dx: Math.cos(a) * d, dy: Math.sin(a) * d, life: 600 + Math.random() * 300 })
        }
    }

    Component { id: ghost; Ghost {} }

    Component {
        id: particle
        Rectangle {
            id: p
            property real startX
            property real startY
            property real dx
            property real dy
            property int life: 700
            width: 6; height: 6; radius: 2
            color: Theme.textDim
            z: 100
            ParallelAnimation {
                running: true
                NumberAnimation { target: p; property: "x"; to: p.startX + p.dx; duration: Theme.dur(p.life); easing.type: Easing.OutCubic }
                NumberAnimation { target: p; property: "y"; to: p.startY + p.dy; duration: Theme.dur(p.life); easing.type: Easing.OutCubic }
                NumberAnimation { target: p; property: "opacity"; to: 0; duration: Theme.dur(p.life) }
                NumberAnimation { target: p; property: "scale"; to: 0.2; duration: Theme.dur(p.life) }
                onFinished: p.destroy()
            }
        }
    }
}
