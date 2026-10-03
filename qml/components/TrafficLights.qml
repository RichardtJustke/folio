import QtQuick
import Folio

Row {
    id: root

    required property var window
    property bool hovered: hover.hovered

    spacing: 8

    HoverHandler { id: hover }

    component Light: Rectangle {
        id: light
        property color base
        property int kind // 0 fechar, 1 minimizar, 2 zoom
        signal activated

        width: 12; height: 12; radius: 6
        color: root.window.active || root.hovered ? base : Theme.lightInactive
        border.width: 0.5
        border.color: Qt.darker(color, 1.35)

        // glifos só aparecem no hover do grupo
        Item {
            anchors.centerIn: parent
            width: 6; height: 6
            visible: root.hovered
            opacity: area.pressed ? 0.9 : 0.6

            Rectangle { // traço horizontal (todos)
                anchors.centerIn: parent
                width: light.kind === 0 ? 8 : 7; height: 1.4; radius: 0.7
                color: "#3b0b0b"
                rotation: light.kind === 0 ? 45 : 0
            }
            Rectangle { // traço vertical (fechar/zoom)
                anchors.centerIn: parent
                visible: light.kind !== 1
                width: light.kind === 0 ? 8 : 7; height: 1.4; radius: 0.7
                color: "#3b0b0b"
                rotation: light.kind === 0 ? -45 : 90
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -2
            onClicked: light.activated()
        }
    }

    Light { base: Theme.close; kind: 0; onActivated: root.window.close() }
    Light { base: Theme.minimize; kind: 1; onActivated: root.window.showMinimized() }
    Light {
        base: Theme.zoom; kind: 2
        onActivated: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
    }
}
