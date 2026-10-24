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
    signal addCloud
    signal topClicked

    signal navigate(string path)
    signal tagClicked(string tag)
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
            height: section === "" ? 0 : root.compact ? 16 : 30
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
            // ── Espaço Livre ──
            Repeater {
                model: root.places
                delegate: Item {
                    required property var model
                    // só mostra o espaço livre para volumes montados (grupo "Locais" exceto Computador)
                    visible: model.freeSpace && !model.path.startsWith("/") && model.path !== "/" && model.group === "Locais"
                    width: parent.width
                    height: visible ? 16 : 0
                    Text {
                        visible: !root.compact
                        anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: model.freeSpace || ""
                        color: Theme.textFaint
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
            Item { // título "Etiquetas" (no modo só-ícones, um divisor)
                width: parent.width
                height: root.compact ? 16 : 30
                Text {
                    visible: !root.compact
                    x: 18; y: 12
                    text: "Etiquetas"
                    color: Theme.textFaint
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: root.compact
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                    height: 1
                    color: Theme.border
                }
            }
            Flow { // bolinhas: clique busca os itens com a etiqueta
                x: root.compact ? (parent.width - width) / 2 : 18
                width: root.compact ? 14 : parent.width - 36
                spacing: root.compact ? 8 : 10
                topPadding: 4; bottomPadding: 8
                Repeater {
                    model: Theme.tagNames
                    delegate: Rectangle {
                        required property string modelData
                        width: 14; height: 14; radius: 7
                        color: Theme.tagColor(modelData)
                        scale: tagArea.containsMouse ? 1.2 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.dur(100) } }
                        MouseArea {
                            id: tagArea
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.text: parent.modelData
                            ToolTip.delay: 400
                            onClicked: root.tagClicked(parent.modelData)
                        }
                    }
                }
            }
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
                name: "Adicionar nuvem…"
                icon: "weather-overcast-symbolic"
                onClicked: root.addCloud()
            }
            // ── Smart Folders ──
            Repeater {
                model: root.places.smartFolders()
                delegate: SidebarItem {
                    width: parent.width
                    compact: root.compact
                    name: modelData.name
                    icon: modelData.icon
                    placePath: modelData.path
                    selected: modelData.path === root.currentPath
                    onClicked: root.navigate(modelData.path)
                }
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
            freeSpace: model.freeSpace
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