import QtQuick
import Folio

Rectangle {
    id: root

    property bool canGoBack
    property bool canGoForward
    signal back
    signal forward

    width: 72; height: 32
    radius: height / 2
    color: Theme.pillBg
    border.width: 1
    border.color: Theme.border

    component Chevron: Item {
        id: btn
        property bool enabledState
        property bool flip
        signal activated

        width: root.width / 2; height: root.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            color: area.containsMouse && btn.enabledState ? Theme.hover : "transparent"
        }
        Image {
            anchors.centerIn: parent
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: Theme.icon(btn.flip ? "go-next-symbolic" : "go-previous-symbolic",
                               btn.enabledState ? Theme.text : Theme.textFaint)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabledState
            onClicked: btn.activated()
        }
    }

    Row {
        Chevron { enabledState: root.canGoBack; onActivated: root.back() }
        Chevron { enabledState: root.canGoForward; flip: true; onActivated: root.forward() }
    }

    Rectangle { // divisor
        anchors.centerIn: parent
        width: 1; height: parent.height - 14
        color: Theme.border
    }
}
