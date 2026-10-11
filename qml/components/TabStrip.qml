import QtQuick
import Folio

// abas em pílula + botões de nova aba e de dividir a janela; soltar arquivos numa aba envia para a pasta dela
Item {
    id: root

    required property ListModel tabs
    property int currentIndex: 0
    property bool splitActive: false
    property int splitLeft: -1
    property int splitRight: -1

    signal newTab
    signal toggleSplit
    signal selected(int index)
    signal closed(int index)
    signal dropped(var drop, int index)

    height: 34

    readonly property int buttonsWidth: 2 * 30 + 6
    readonly property real tabWidth: Math.max(60, Math.min(200,
        (width - 28 - buttonsWidth - tabs.count * 6) / Math.max(1, tabs.count)))

    Row {
        id: tabRow
        anchors { left: parent.left; leftMargin: 14; top: parent.top; bottom: parent.bottom }
        spacing: 6

        Repeater {
            model: root.tabs
            delegate: Rectangle {
                id: tab
                required property int index
                required property string title
                readonly property bool current: index === root.currentIndex
                readonly property bool inSplit: root.splitActive && (index === root.splitLeft || index === root.splitRight)

                width: root.tabWidth
                height: 28
                radius: 14
                color: drop.containsDrag ? Theme.accentGlow
                     : current ? Theme.selected : area.containsMouse ? Theme.hover : Theme.overlay(0.03)
                border.width: current || inSplit || drop.containsDrag ? 1 : 0
                border.color: drop.containsDrag ? Theme.accent : current && root.splitActive ? Theme.tint(Theme.accent, 0.6) : Theme.border

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

    // nova aba
    Rectangle {
        anchors { left: tabRow.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
        width: 28; height: 28; radius: 14
        color: newArea.containsMouse ? Theme.hover : "transparent"
        Image {
            anchors.centerIn: parent
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: Theme.icon("list-add-symbolic", Theme.textDim)
        }
        MouseArea { id: newArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.newTab() }
    }

    // dividir a janela (duas abas lado a lado)
    Rectangle {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        width: 28; height: 28; radius: 14
        color: root.splitActive ? Theme.accentGlow : splitArea.containsMouse ? Theme.hover : "transparent"
        Rectangle { // glifo: janela dividida ao meio
            anchors.centerIn: parent
            width: 15; height: 11; radius: 3
            color: "transparent"
            border.width: 1.2
            border.color: root.splitActive ? Theme.accent : Theme.textDim
            Rectangle { x: parent.width / 2 - 0.5; y: 0; width: 1.2; height: parent.height; color: parent.border.color }
        }
        MouseArea { id: splitArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleSplit() }
    }
}
