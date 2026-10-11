import QtQuick
import Folio

// Cópia visual de um item: voa até um destino (Lixeira, pasta…) ou encolhe e some no lugar.
Item {
    id: root

    property var entry
    property real fromX // centro de origem, em coordenadas da janela
    property real fromY
    property real toX
    property real toY
    property real size: 56
    property int delay: 0
    property bool flying: true

    signal arrived

    width: size; height: size
    x: fromX - size / 2
    y: fromY - size / 2
    z: 100
    transformOrigin: Item.Center

    FolderIcon {
        visible: root.entry && root.entry.isDir
        anchors.fill: parent
        glyph: root.entry ? root.entry.glyph || "" : ""
    }
    Image {
        visible: root.entry && !root.entry.isDir
        anchors.fill: parent
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: root.entry && !root.entry.isDir ? Theme.icon(root.entry.icon) : ""
    }

    SequentialAnimation {
        id: anim
        PauseAnimation { duration: Theme.dur(root.delay) }
        ParallelAnimation {
            // eixos com curvas diferentes desenham um arco em vez de uma reta
            NumberAnimation {
                target: root; property: "x"; to: root.toX - root.size / 2
                duration: Theme.dur(root.flying ? 540 : 1); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "y"; to: root.toY - root.size / 2
                duration: Theme.dur(root.flying ? 540 : 1); easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root; property: "scale"; to: root.flying ? 0.2 : 0.55
                duration: Theme.dur(root.flying ? 540 : 260); easing.type: Easing.InOutQuad
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.dur(root.flying ? 320 : 40) }
                NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.dur(root.flying ? 220 : 220) }
            }
        }
        ScriptAction { script: { root.arrived(); root.destroy() } }
    }

    Component.onCompleted: anim.start()
}
