import QtQuick
import QtQuick.Controls
import Folio

MenuItem {
    id: root
    property bool tick: false // marca ✓ sem tornar o item checkable
    property string shortcut   // dica de atalho à direita (só texto)
    implicitHeight: visible ? 26 : 0
    leftPadding: 10
    rightPadding: 10

    contentItem: Item {
        implicitWidth: row.implicitWidth + (root.shortcut ? hint.implicitWidth + 28 : 0)
        implicitHeight: row.implicitHeight
        Text {
            id: hint
            visible: root.shortcut !== ""
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.shortcut
            color: root.highlighted ? Qt.rgba(1, 1, 1, 0.75) : Theme.textFaint
            font.pixelSize: Theme.fontSize - 1
        }
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
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
    }

    background: Rectangle {
        radius: 6
        color: root.highlighted && root.enabled ? Theme.accent : "transparent"
    }
}
