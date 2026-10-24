import QtQuick
import QtQuick.Controls
import Folio

// Página Início (folio:home): acesso rápido às pastas, discos com espaço livre e arquivos recentes.
Item {
    id: root

    required property PlacesModel places
    required property FileOps ops

    signal navigate(string path)
    signal reveal(string path)

    property var pinned: []
    property var frequent: [] // pastas dos recentes que ainda não estão fixadas
    property var drives: []
    property var recent: []

    function refresh() {
        pinned = places.quickAccess()
        drives = places.drives()
        const items = finder.recent(40)
        recent = items.slice(0, 12)
        const known = new Set(pinned.map(p => p.path))
        known.add(Settings.home)
        const dirs = []
        for (const it of items) {
            const dir = it.isDir ? it.path : ops.parentDir(it.path)
            if (known.has(dir) || dirs.includes(dir)) continue
            dirs.push(dir)
            if (dirs.length >= 4) break
        }
        frequent = dirs.map(d => ({ name: d.split("/").pop(), path: d, glyph: "", removable: false, frequent: true }))
    }

    function activate(item) {
        if (item.isDir) root.navigate(item.path)
        else root.ops.open(item.path)
    }

    QuickFind { id: finder }
    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()
    Connections {
        target: root.places
        function onModelReset() { root.refresh() }
    }

    component SectionTitle: Item {
        id: st
        property string text
        property bool open: true
        width: parent ? parent.width : 0
        height: 30
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12
                sourceSize: Qt.size(24, 24)
                source: Theme.icon("pan-down-symbolic", Theme.textDim)
                rotation: st.open ? 0 : -90
                Behavior on rotation { NumberAnimation { duration: Theme.dur(140) } }
            }
            Text {
                text: st.text
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.DemiBold
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.open = !st.open }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: body.height + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: body
            x: 22
            y: 18
            width: flick.width - 44
            spacing: 6

            Text {
                text: "Início"
                color: Theme.text
                font.pixelSize: Theme.fontSize + 9
                font.weight: Font.Bold
                bottomPadding: 6
            }

            // ── Acesso rápido ──
            SectionTitle { id: quickTitle; text: "Acesso rápido" }
            Flow {
                id: quickFlow
                visible: quickTitle.open
                width: parent.width
                spacing: 8
                readonly property int tileW: Math.max(104, Math.floor((width + spacing) / Math.max(1, Math.floor((width + spacing) / 120))) - spacing)
                Repeater {
                    model: root.pinned.concat(root.frequent)
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool isPinned: !modelData.frequent
                        width: quickFlow.tileW
                        height: 86
                        radius: 10
                        color: tileArea.containsMouse ? Theme.buttonHover : Theme.subtle
                        border.width: drop.containsDrag ? 1.5 : 1
                        border.color: drop.containsDrag ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.dur(100) } }

                        FolderIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            width: 38; height: 38
                            glyph: tile.modelData.glyph
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8; bottomMargin: 10 }
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            color: Theme.text
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                if (e.button === Qt.RightButton) { folderMenu.item = tile.modelData; folderMenu.popup(); return }
                                root.navigate(tile.modelData.path)
                            }
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            onDropped: d => {
                                if (!d.hasUrls) return
                                root.ops.dropUrls(d.urls, tile.modelData.path)
                                d.accept(Qt.CopyAction)
                            }
                        }
                        // alfinete: fixadas sempre; as outras ao passar o mouse (clique fixa/desafixa)
                        Rectangle {
                            anchors { top: parent.top; right: parent.right; margins: 5 }
                            width: 22; height: 22; radius: 11
                            visible: tile.isPinned || tileArea.containsMouse || pinArea.containsMouse
                            color: pinArea.containsMouse ? Theme.hover : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 12; height: 12
                                sourceSize: Qt.size(24, 24)
                                source: Theme.icon("view-pin-symbolic", tile.isPinned ? Theme.textDim : Theme.textFaint)
                                rotation: tile.isPinned ? 0 : 35
                            }
                            MouseArea {
                                id: pinArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: tile.isPinned && !tile.modelData.removable ? Qt.ArrowCursor : Qt.PointingHandCursor
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: !tile.isPinned ? "Fixar" : tile.modelData.removable ? "Desafixar" : "Pasta padrão"
                                onClicked: {
                                    if (!tile.isPinned) root.places.addFavorite(tile.modelData.path)
                                    else if (tile.modelData.removable) root.places.removeFavorite(tile.modelData.path)
                                }
                            }
                        }
                    }
                }
            }

            // ── Discos ──
            Item { width: 1; height: 6 }
            SectionTitle { id: drivesTitle; text: "Discos"; visible: root.drives.length > 0 }
            Flow {
                id: driveFlow
                visible: drivesTitle.open && root.drives.length > 0
                width: parent.width
                spacing: 8
                readonly property int cardW: Math.max(220, Math.floor((width + spacing) / Math.max(1, Math.floor((width + spacing) / 260))) - spacing)
                Repeater {
                    model: root.drives
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property real used: 1 - modelData.free / modelData.total
                        width: driveFlow.cardW
                        height: 64
                        radius: 10
                        color: driveArea.containsMouse ? Theme.buttonHover : Theme.subtle
                        border.width: 1
                        border.color: Theme.border
                        Image {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26
                            sourceSize: Qt.size(52, 52)
                            source: Theme.icon(card.modelData.icon, Theme.textDim)
                        }
                        Column {
                            anchors { left: parent.left; leftMargin: 52; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 5
                            Text {
                                width: parent.width
                                text: card.modelData.name
                                color: Theme.text
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                width: parent.width; height: 5; radius: 3
                                color: Theme.pillBg
                                Rectangle {
                                    width: Math.max(height, parent.width * card.used); height: parent.height; radius: 3
                                    color: card.used > 0.9 ? Theme.danger : Theme.accent
                                }
                            }
                            Text {
                                width: parent.width
                                text: Theme.sizeLabel(card.modelData.free) + " livres de " + Theme.sizeLabel(card.modelData.total)
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: driveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.navigate(card.modelData.path)
                        }
                    }
                }
            }

            // ── Arquivos recentes ──
            Item { width: 1; height: 6 }
            SectionTitle { id: recentTitle; text: "Arquivos recentes" }
            Text {
                visible: recentTitle.open && root.recent.length === 0
                text: "Os arquivos que você abrir aparecem aqui."
                color: Theme.textFaint
                font.pixelSize: Theme.fontSize - 1
                leftPadding: 4
            }
            Column {
                visible: recentTitle.open
                width: parent.width
                Repeater {
                    model: root.recent
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Theme.listRowHeight + 6
                        radius: 6
                        color: rowArea.containsMouse ? Theme.hover : "transparent"
                        Rectangle { // divisor entre linhas
                            visible: row.index > 0
                            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 8 }
                            height: 1
                            color: Theme.border
                        }
                        Image {
                            id: rowIcon
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 20
                            sourceSize: Qt.size(40, 40)
                            asynchronous: true
                            source: row.modelData.isDir ? Theme.fileIcon("folder", "")
                                  : Settings.fileIcons === "system" ? Theme.icon(row.modelData.icon) + "&pack=0"
                                  : Theme.fileIcon(row.modelData.icon, row.modelData.name)
                        }
                        Text {
                            id: rowName
                            anchors { left: rowIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: (row.width - 60) * 0.42
                            text: row.modelData.name
                            color: Theme.text
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideMiddle
                        }
                        Text {
                            anchors { left: rowName.right; leftMargin: 12; right: when.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: row.modelData.location
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideMiddle
                        }
                        Text {
                            id: when
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: Theme.dateLabel(row.modelData.used)
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontSize - 2
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                if (e.button === Qt.RightButton) { recentMenu.item = row.modelData; recentMenu.popup(); return }
                                root.activate(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    GlassMenu {
        id: folderMenu
        property var item: ({})
        GlassMenuItem { text: "Abrir"; onTriggered: root.navigate(folderMenu.item.path) }
        GlassMenuItem {
            text: folderMenu.item.frequent ? "Fixar no Acesso rápido" : "Desafixar"
            enabled: folderMenu.item.frequent || folderMenu.item.removable
            onTriggered: folderMenu.item.frequent ? root.places.addFavorite(folderMenu.item.path)
                                                  : root.places.removeFavorite(folderMenu.item.path)
        }
        GlassMenuItem { text: "Copiar Caminho"; onTriggered: root.ops.copyText(folderMenu.item.path) }
    }

    GlassMenu {
        id: recentMenu
        property var item: ({})
        GlassMenuItem { text: "Abrir"; onTriggered: root.activate(recentMenu.item) }
        GlassMenuItem { text: "Mostrar na Pasta"; onTriggered: root.reveal(recentMenu.item.path) }
        GlassMenuItem { text: "Copiar Caminho"; onTriggered: root.ops.copyText(recentMenu.item.path) }
    }
}
