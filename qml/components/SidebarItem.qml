import QtQuick
import Folio

Item {
    id: root

    property string name
    property string icon
    property bool selected: false
    property bool ejectable: false

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
        color: drop.containsDrag ? Qt.rgba(0.04, 0.52, 1, 0.25)
             : root.selected ? Theme.selected : mouse.containsMouse ? Theme.hover : "transparent"
        border.width: root.selected || drop.containsDrag ? 1 : 0
        border.color: drop.containsDrag ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: eject.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Theme.icon(root.icon + ",folder-symbolic", Theme.sidebarIcon)
        }
        Text {
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
        width: root.ejectable ? 14 : 0; height: 14
        visible: root.ejectable
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
