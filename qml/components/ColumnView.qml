import QtQuick
import QtQuick.Controls
import Folio

// Vista em colunas (Miller columns): a pasta atual na primeira coluna; escolher uma
// subpasta abre a coluna seguinte. Reaproveita FileModel para listar cada coluna.
Item {
    id: root

    required property FileModel fileModel
    required property FileOps ops
    required property PlacesModel places

    // colunas: { path } — a 0 é a pasta raiz (usa o fileModel da vista)
    property ListModel columns: ListModel {}

    // coluna mais à direita (nível mais profundo)
    readonly property int activeIndex: Math.max(0, columns.count - 1)
    readonly property string activePath: activeIndex >= 0 && columns.count > 0 ? columns.get(activeIndex).path : fileModel.path

    signal activate(var entry)
    signal openInNewTab(string path)
    signal requestDelete(var paths, bool permanent)
    signal requestEmptyTrash
    signal quickLook
    signal showProperties(var paths)
    signal openWith(string path)
    signal renameMany(var paths)
    signal promptSelectPattern
    signal openTerminalHere(string dir)

    function reset() {
        columns.clear()
        columns.append({ path: root.fileModel.path })
    }

    Connections {
        target: root.fileModel
        function onPathChanged() { root.reset() }
    }
    Component.onCompleted: reset()

    // clicar numa pasta da coluna i: substitui/estende as colunas seguintes
    function openFolder(i, path) {
        // remove colunas depois de i
        while (columns.count > i + 1)
            columns.remove(columns.count - 1)
        columns.append({ path: path })
    }

    // colar/mover na coluna ativa
    function pasteIntoActive() { root.ops.paste(activePath) }

    // ── barra de caminho das colunas ──
    Rectangle {
        id: crumbBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 26
        color: Theme.overlay(0.03)
        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 2
            Repeater {
                model: root.columns
                delegate: Row {
                    id: crumbRow
                    required property string path
                    required property int index
                    spacing: 2
                    Rectangle {
                        width: crumb.implicitWidth + 12; height: 20; radius: 10
                        color: mouse.containsMouse ? Theme.hover : "transparent"
                        Text {
                            id: crumb
                            anchors.centerIn: parent
                            text: {
                                const p = crumbRow.path
                                if (p === "folio:recent") return "Recentes"
                                if (p === "/") return "Computador"
                                const parts = p.split("/")
                                return parts[parts.length - 1] || "/"
                            }
                            color: Theme.text
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                while (root.columns.count > crumbRow.index + 1)
                                    root.columns.remove(root.columns.count - 1)
                            }
                        }
                    }
                    Text {
                        visible: crumbRow.index < root.columns.count - 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ── as colunas ──
    ListView {
        id: columnsView
        anchors { left: parent.left; right: parent.right; top: crumbBar.bottom; bottom: parent.bottom }
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        model: root.columns
        spacing: 0

        delegate: Rectangle {
            id: column
            required property string path
            required property int index
            readonly property var model: column.index === 0 ? root.fileModel : ownModel
            readonly property bool isLast: column.index === root.columns.count - 1

            width: 220
            height: ListView.view.height
            color: column.index % 2 === 1 ? Theme.overlay(0.02) : "transparent"
            border.width: column.isLast ? 0 : 1
            border.color: Theme.border

            // colunas 1..n listam com um modelo próprio; a 0 usa o da vista
            FileModel {
                id: ownModel
                columns: 1
                groupByDate: false
                path: column.index > 0 ? column.path : ""
            }

            ListView {
                id: colList
                anchors.fill: parent
                anchors.topMargin: 4
                clip: true
                model: column.model ? column.model.rows : null
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 5; radius: 3
                        color: Qt.rgba(1, 1, 1, 0.2)
                        opacity: parent.pressed ? 1 : 0
                    }
                }
                delegate: Loader {
                    id: colRow
                    required property string kind
                    required property string title
                    required property var items
                    width: colList.width
                    height: kind === "header" ? Theme.sectionHeaderHeight : Theme.listRowHeight + 6
                    sourceComponent: kind === "header" ? headerComp : itemComp

                    Component {
                        id: headerComp
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.overlay(0.05)
                            Text {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                text: colRow.title
                                color: Theme.textFaint
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                    Component {
                        id: itemComp
                        Rectangle {
                            anchors.fill: parent
                            color: area.containsMouse ? Theme.hover
                                 : column.model && column.model.selectionRevision >= 0 && column.model.isSelected(colRow.items[0].index) ? Theme.selected : "transparent"
                            Row {
                                anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                FolderIcon {
                                    visible: colRow.items[0].isDir
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18; height: 18
                                    glyph: colRow.items[0].glyph || ""
                                }
                                Image {
                                    visible: !colRow.items[0].isDir
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16; height: 16
                                    sourceSize: Qt.size(32, 32)
                                    asynchronous: true
                                    source: Settings.fileIcons === "system" ? Theme.icon(colRow.items[0].icon) + "&pack=0"
                                          : Theme.fileIcon(colRow.items[0].icon, colRow.items[0].name)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - 40)
                                    text: colRow.items[0].name
                                    color: Theme.text
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                            }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: e => {
                                    const m = column.model
                                    const entry = colRow.items[0]
                                    if (!m || !entry) return
                                    if (e.button === Qt.MiddleButton && entry.isDir) {
                                        root.openInNewTab(entry.path)
                                        return
                                    }
                                    if (entry.isDir) {
                                        root.openFolder(column.index, entry.path)
                                    } else {
                                        m.select(entry.index, e.modifiers)
                                        root.activate(entry)
                                    }
                                }
                                onDoubleClicked: e => {
                                    const entry = colRow.items[0]
                                    if (entry && entry.isDir)
                                        root.openFolder(column.index, entry.path)
                                    else if (entry)
                                        root.activate(entry)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: column.model && column.model.count === 0 && !column.model.loading
                text: "Pasta vazia"
                color: Theme.textFaint
                font.pixelSize: 12
            }
        }
    }
}
