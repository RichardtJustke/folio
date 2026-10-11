import QtQuick
import QtQuick.Controls
import Folio

Rectangle {
    id: root

    required property var window
    required property PlacesModel places
    property string currentPath
    property bool compact: false
    signal openSettings
    signal addFolder
    signal connectServer
    signal topClicked

    signal navigate(string path)
    signal dropOnPlace(var drop, string path)

    // centro do ícone de um lugar, em coordenadas da janela (null se a barra estiver oculta/fora da vista)
    function targetFor(path) {
        const it = placeItem(path)
        if (!it || !root.visible) return null
        return it.mapToItem(null, root.compact ? it.width / 2 : 26, it.height / 2)
    }

    function pulse(path) {
        const it = placeItem(path)
        if (it) it.pulse()
    }

    function placeItem(path) {
        const kids = list.contentItem.children
        for (let i = 0; i < kids.length; i++)
            if (kids[i].placePath === path) return kids[i]
        return null
    }

    radius: Theme.radius - 4
    color: Theme.sidebarBg
    border.width: 1
    border.color: Theme.border

    // topo: marca do app (também arrasta a janela)
    MouseArea {
        property point pressPos
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: list.top }
        onPressed: e => { pressPos = Qt.point(e.x, e.y); root.topClicked() }
        onPositionChanged: e => {
            if (pressed && Math.abs(e.x - pressPos.x) + Math.abs(e.y - pressPos.y) > 8) root.window.startSystemMove()
        }
    }
    Row {
        x: root.compact ? (parent.width - 22) / 2 : 18
        y: 13
        spacing: 8
        Image {
            width: 22; height: 22
            sourceSize: Qt.size(44, 44)
            source: "qrc:/qt/qml/Folio/assets/folio.svg"
        }
        Text {
            visible: !root.compact
            anchors.verticalCenter: parent.verticalCenter
            text: "Folio"
            color: Theme.text
            font.pixelSize: Theme.fontSize + 1
            font.weight: Font.Bold
        }
    }

    // soltar pastas no espaço livre da sidebar = adicionar aos Favoritos
    DropArea {
        anchors.fill: list
        onDropped: d => {
            if (!d.hasUrls) return
            root.places.addFavoriteUrls(d.urls)
            d.accept(Qt.LinkAction)
        }
    }

    ListView {
        id: list
        anchors { fill: parent; topMargin: 48; bottomMargin: 46 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.places

        section.property: "group"
        section.delegate: Item {
            required property string section
            width: ListView.view.width
            height: root.compact ? 16 : 30
            clip: true
            Text {
                visible: !root.compact
                x: 18; y: 12
                text: parent.section
                color: Theme.textFaint
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Rectangle { // divisor no modo só-ícones
                visible: root.compact
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                height: 1
                color: Theme.border
            }
        }

        footer: Column {
            width: ListView.view.width
            SidebarItem {
                width: parent.width
                compact: root.compact
                name: "Conectar ao servidor…"
                icon: "network-server-symbolic,folder-remote-symbolic"
                onClicked: root.connectServer()
            }
            SidebarItem {
                width: parent.width
                compact: root.compact
                name: "Adicionar pasta…"
                icon: "list-add-symbolic"
                onClicked: root.addFolder()
            }
        }

        delegate: SidebarItem {
            required property var model

            width: ListView.view.width
            compact: root.compact
            placePath: model.path
            name: model.name
            icon: model.icon
            ejectable: model.ejectable
            selected: model.path === root.currentPath
            onClicked: root.navigate(model.path)
            onEjectClicked: root.places.eject(model.device)
            onDropped: d => root.dropOnPlace(d, model.path)
            onRightClicked: (x, y) => {
                if (!model.favorite) return
                menu.path = model.path
                menu.popup()
            }
        }
    }

    // rodapé: configurações
    SidebarItem {
        id: settingsItem
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
        compact: root.compact
        name: "Configurações"
        icon: "preferences-system-symbolic"
        onClicked: root.openSettings()
    }

    GlassMenu {
        id: menu
        property string path
        GlassMenuItem { text: "Remover dos Favoritos"; onTriggered: root.places.removeFavorite(menu.path) }
    }
}
