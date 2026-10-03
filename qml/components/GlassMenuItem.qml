import QtQuick
import QtQuick.Controls
import Folio

MenuItem {
    id: root
    property bool tick: false // marca ✓ sem tornar o item checkable
    implicitHeight: visible ? 26 : 0
    leftPadding: 10
    rightPadding: 10

    contentItem: Row {
        spacing: 8
        Text {
            width: 12
            text: root.tick ? "✓" : ""
            color: Theme.text
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.text
            color: !root.enabled ? Theme.textFaint : root.highlighted ? "white" : Theme.text
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: 6
        color: root.highlighted && root.enabled ? Theme.accent : "transparent"
    }
}
