import QtQuick
import QtQuick.Controls
import Folio

Rectangle {
    id: root

    required property var window
    required property PlacesModel places
    property string currentPath

    signal navigate(string path)
    signal dropOnPlace(var drop, string path)

    radius: Theme.radius - 4
    color: Theme.sidebarBg
    border.width: 1
    border.color: Theme.border

    TrafficLights {
        id: lights
        window: root.window
        x: 16; y: 16
    }

    // área vazia do topo também arrasta a janela
    MouseArea {
        anchors { left: lights.right; right: parent.right; top: parent.top; bottom: list.top }
        onPressed: root.window.startSystemMove()
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
        anchors { fill: parent; topMargin: 48; bottomMargin: 8 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.places

        section.property: "group"
        section.delegate: Text {
            required property string section
            width: ListView.view.width
            height: 30
            leftPadding: 18
            topPadding: 12
            text: section
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        delegate: SidebarItem {
            required property var model

            width: ListView.view.width
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

    GlassMenu {
        id: menu
        property string path
        GlassMenuItem { text: "Remover dos Favoritos"; onTriggered: root.places.removeFavorite(menu.path) }
    }
}
