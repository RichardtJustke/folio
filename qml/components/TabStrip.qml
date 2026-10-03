import QtQuick
import Folio

// abas em pílula (aparece com 2+ abas); soltar arquivos numa aba envia para a pasta dela
Item {
    id: root

    required property ListModel tabs
    property int currentIndex: 0

    signal selected(int index)
    signal closed(int index)
    signal dropped(var drop, int index)

    height: 34

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 6

        Repeater {
            model: root.tabs
            delegate: Rectangle {
                id: tab
                required property int index
                required property string title
                readonly property bool current: index === root.currentIndex

                width: (parent.width - (root.tabs.count - 1) * 6) / root.tabs.count
                height: 28
                radius: 14
                color: drop.containsDrag ? Qt.rgba(0.04, 0.52, 1, 0.25)
                     : current ? Theme.selected : area.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.03)
                border.width: current || drop.containsDrag ? 1 : 0
                border.color: drop.containsDrag ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 48)
                    text: tab.title
                    color: tab.current ? Theme.text : Theme.textDim
                    font.pixelSize: 12
                    font.weight: tab.current ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: e => e.button === Qt.MiddleButton ? root.closed(tab.index) : root.selected(tab.index)
                }

                Rectangle { // fechar
                    visible: area.containsMouse || closeArea.containsMouse
                    anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                    width: 16; height: 16; radius: 8
                    color: closeArea.containsMouse ? Theme.hover : "transparent"
                    Image {
                        anchors.centerIn: parent
                        width: 10; height: 10
                        sourceSize: Qt.size(20, 20)
                        source: Theme.icon("window-close-symbolic", Theme.textDim)
                    }
                    MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closed(tab.index) }
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    onEntered: root.selected(tab.index) // abre a aba ao passar com arquivos
                    onDropped: d => root.dropped(d, tab.index)
                }
            }
        }
    }
}
