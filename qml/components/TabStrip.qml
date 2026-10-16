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

    // fecha com animação (a pílula encolhe e as vizinhas deslizam); com uma aba só, fecha na hora
    function requestClose(i) {
        const it = tabRepeater.itemAt(i)
        if (it && root.tabs.count > 1) it.startClose()
        else root.closed(i)
    }

    function closeOthers(i) {
        for (let idx = root.tabs.count - 1; idx >= 0; idx--) {
            if (idx !== i) root.closed(idx)
        }
    }

    function closeRight(i) {
        for (let idx = root.tabs.count - 1; idx > i; idx--) {
            root.closed(idx)
        }
    }

    readonly property int buttonsWidth: 2 * 30 + 6
    readonly property real tabWidth: Math.max(60, Math.min(200,
        (width - 28 - buttonsWidth - tabs.count * 6) / Math.max(1, tabs.count)))

    Row {
        id: tabRow
        anchors { left: parent.left; leftMargin: 14; top: parent.top; bottom: parent.bottom }
        spacing: 6

        Repeater {
            id: tabRepeater
            model: root.tabs
            delegate: Rectangle {
                id: tab
                required property int index
                required property string title
                readonly property bool current: index === root.currentIndex
                readonly property bool inSplit: root.splitActive && (index === root.splitLeft || index === root.splitRight)

                property bool shown: false
                property bool closing: false
                function startClose() { closing = true; closeTimer.start() }
                Timer { id: closeTimer; interval: Theme.dur(190); onTriggered: root.closed(tab.index) }
                Component.onCompleted: shown = true

                width: shown && !closing ? root.tabWidth : 0
                Behavior on width { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
                opacity: shown && !closing ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
                clip: true
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
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: e => {
                        if (e.button === Qt.MiddleButton) {
                            root.requestClose(tab.index)
                        } else if (e.button === Qt.RightButton) {
                            root.selected(tab.index)
                            tabMenu.tabIdx = tab.index
                            tabMenu.popup()
                        } else {
                            root.selected(tab.index)
                        }
                    }
                    onPressAndHold: {
                        // drag para reordenar abas
                        if (root.tabs.count > 1) {
                            dragTarget.index = tab.index
                            dragTarget.title = tab.title
                            dragTarget.visible = true
                            dragTarget.x = tab.mapToItem(root, 0, 0).x
                            dragTarget.y = tab.y
                            dragTarget.opacity = 0.9
                            tab.opacity = 0.3
                        }
                    }
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
                    MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.requestClose(tab.index) }
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    onEntered: root.selected(tab.index) // abre a aba ao passar com arquivos
                    onDropped: d => root.dropped(d, tab.index)
                }
            }
        }

        // aba fantasma para arrastar
        Item {
            id: dragTarget
            property int index: -1
            property string title: ""
            visible: false
            height: 28
            z: 10
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Theme.selected
                border.width: 1
                border.color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: dragTarget.title
                    color: Theme.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                anchors.fill: parent
                drag.target: parent
                drag.axis: Drag.XAxis
                onReleased: {
                    dragTarget.visible = false
                    // encontra a posição mais próxima para soltar
                    const dropX = dragTarget.x + dragTarget.width / 2
                    let targetIdx = dragTarget.index
                    for (let j = 0; j < tabRepeater.count; j++) {
                        const it = tabRepeater.itemAt(j)
                        if (!it) continue
                        const cx = it.x + tabRow.x + it.width / 2
                        if (dropX < cx) { targetIdx = j; break }
                        targetIdx = j + 1
                    }
                    if (targetIdx !== dragTarget.index && targetIdx >= 0 && targetIdx < tabRepeater.count) {
                        // move a aba no ListModel
                        const data = root.tabs.get(dragTarget.index)
                        root.tabs.remove(dragTarget.index)
                        root.tabs.insert(targetIdx > dragTarget.index ? targetIdx - 1 : targetIdx, data)
                        if (root.currentIndex === dragTarget.index) {
                            root.currentIndex = targetIdx > dragTarget.index ? targetIdx - 1 : targetIdx
                        }
                    }
                    // restaura a opacidade
                    for (let j = 0; j < tabRepeater.count; j++) {
                        const it = tabRepeater.itemAt(j)
                        if (it) it.opacity = 1
                    }
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

    GlassMenu {
        id: tabMenu
        property int tabIdx: -1
        GlassMenuItem {
            text: "Fechar Aba"
            onTriggered: root.requestClose(tabMenu.tabIdx)
        }
        GlassMenuItem {
            text: "Fechar Outras Abas"
            visible: root.tabs.count > 1
            onTriggered: root.closeOthers(tabMenu.tabIdx)
        }
        GlassMenuItem {
            text: "Fechar Abas à Direita"
            visible: tabMenu.tabIdx < root.tabs.count - 1
            onTriggered: root.closeRight(tabMenu.tabIdx)
        }
        GlassMenuItem {
            text: "Nova Aba"
            onTriggered: root.newTab()
        }
    }
}