import QtQuick
import QtQuick.Controls
import Folio

Item {
    id: root

    property string name
    property string icon
    property bool selected: false
    property bool ejectable: false
    property bool compact: false
    property string placePath // caminho que o item representa (alvo das animações de voo)
    property real iconScale: 1

    // pulso quando algo chega (item solto, Lixeira recebendo arquivos)
    function pulse() {
        if (!Theme.motion) return
        pulseAnim.restart()
        flash.opacity = 1
        flashFade.restart()
    }
    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "iconScale"; to: 1.35; duration: Theme.dur(140); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "iconScale"; to: 0.92; duration: Theme.dur(130) }
        NumberAnimation { target: root; property: "iconScale"; to: 1; duration: Theme.dur(120) }
    }

    signal clicked
    signal rightClicked(real x, real y)
    signal ejectClicked
    signal dropped(var drop)

    height: 30

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: height / 2
        color: drop.containsDrag ? Theme.accentGlow
             : root.selected ? Theme.selected : mouse.containsMouse ? Theme.hover : "transparent"
        border.width: root.selected || drop.containsDrag ? 1 : 0
        border.color: drop.containsDrag ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.dur(90) } }
    }
    Rectangle { // brilho curto ao receber algo
        id: flash
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: height / 2
        color: Theme.accentGlow
        opacity: 0
        NumberAnimation on opacity { id: flashFade; running: false; to: 0; duration: Theme.dur(700); easing.type: Easing.OutQuad }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.compact ? (parent.width - 16) / 2 : 18
        anchors.right: eject.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            scale: root.iconScale
            sourceSize: Qt.size(32, 32)
            source: Theme.icon(root.icon + ",folder-symbolic", Theme.sidebarIcon)
        }
        Text {
            opacity: root.compact ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
            anchors.verticalCenter: parent.verticalCenter
            width: eject.x - 18 - 24 - 8
            text: root.name
            color: Theme.text
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        ToolTip.visible: root.compact && containsMouse
        ToolTip.text: root.name
        ToolTip.delay: 500
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked(e.x, e.y) : root.clicked()
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: d => root.dropped(d)
    }

    Image {
        id: eject
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: root.ejectable && !root.compact ? 14 : 0; height: 14
        visible: root.ejectable && !root.compact
        opacity: ejectArea.containsMouse ? 1 : 0.6
        sourceSize: Qt.size(28, 28)
        source: Theme.icon("media-eject-symbolic", Theme.textDim)
        MouseArea {
            id: ejectArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: root.ejectClicked()
        }
    }
}
