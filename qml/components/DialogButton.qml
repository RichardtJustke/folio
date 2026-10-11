import QtQuick
import Folio

Rectangle {
    id: root

    property string text
    property bool primary: false
    property bool destructive: false
    signal clicked

    implicitWidth: Math.max(84, label.implicitWidth + 28)
    implicitHeight: 28
    radius: 8
    color: primary ? (destructive ? Theme.danger : Theme.accent) : area.containsMouse ? Theme.overlay(0.14) : Theme.overlay(0.09)
    opacity: area.pressed ? 0.8 : 1

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "white" : Theme.text
        font.pixelSize: Theme.fontSize
        font.weight: root.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
