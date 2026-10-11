import QtQuick
import Folio

// Controles discretos: dois glifos monocromáticos (maximizar, fechar), sem cores de semáforo.
// Fechar só ganha cor no hover. Posição e visibilidade vêm de Settings.windowControls.
Row {
    id: root

    required property var window
    readonly property bool maximized: window.visibility === Window.Maximized || window.visibility === Window.FullScreen

    spacing: 2

    component Control: Rectangle {
        id: c
        property string glyph // minimize | maximize | restore | close
        property bool danger
        signal activated

        width: 28; height: 28; radius: 14
        color: area.containsMouse ? (danger ? Theme.tint(Theme.danger, 0.9) : Theme.hover) : "transparent"

        Canvas {
            anchors.centerIn: parent
            width: 12; height: 12
            property color stroke: area.containsMouse && c.danger ? "white" : Theme.textDim
            onStrokeChanged: requestPaint()
            onPaint: {
                const g = getContext("2d")
                g.reset()
                g.strokeStyle = stroke
                g.lineWidth = 1.4
                g.lineCap = "round"
                g.lineJoin = "round"
                g.beginPath()
                switch (c.glyph) {
                case "minimize": g.moveTo(1.5, 9); g.lineTo(10.5, 9); break
                case "maximize": g.rect(1.5, 1.5, 9, 9); break
                case "restore":
                    g.rect(1.5, 3.5, 7, 7)
                    g.moveTo(4, 1.5); g.lineTo(10.5, 1.5); g.lineTo(10.5, 8)
                    break
                case "close": g.moveTo(2, 2); g.lineTo(10, 10); g.moveTo(10, 2); g.lineTo(2, 10); break
                }
                g.stroke()
            }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: c.activated() }
    }

    Control {
        glyph: root.maximized ? "restore" : "maximize"
        onActivated: root.maximized ? root.window.showNormal() : root.window.showMaximized()
    }
    Control { glyph: "close"; danger: true; onActivated: root.window.close() }
}
