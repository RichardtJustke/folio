import QtQuick
import QtQuick.Controls
import Folio

// Busca rápida (Ctrl+P): digite parte do nome; ↑/↓ escolhem; Enter abre (pasta: navega);
// Shift+Enter mostra o item na pasta. Sem texto: arquivos recentes.
Popup {
    id: root

    required property FileOps ops
    signal navigate(string path)
    signal reveal(string path)

    property int current: 0

    function show() {
        field.text = ""
        current = 0
        finder.search("")
        open()
        field.forceActiveFocus()
    }

    function activate(i, inFolder) {
        const r = finder.results[i]
        if (!r) return
        close()
        if (r.isDir && !inFolder) root.navigate(r.path)
        else if (inFolder) root.reveal(r.path)
        else root.ops.open(r.path)
    }

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round(parent.height * 0.14)
    width: Math.min(560, parent.width - 40)
    padding: 8
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: finder.cancel()

    QuickFind {
        id: finder
        onResultsChanged: root.current = 0
    }
    Timer { id: debounce; interval: 160; onTriggered: finder.search(field.text) }

    background: Rectangle {
        radius: 14
        color: Theme.light ? Qt.rgba(0.98, 0.98, 0.99, 0.97) : Qt.rgba(0.16, 0.16, 0.17, 0.96)
        border.width: 1
        border.color: Theme.borderStrong
    }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.3) }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(140); easing.type: Easing.OutQuad }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.dur(140); easing.type: Easing.OutQuad }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(100) } }

    contentItem: Column {
        spacing: 6

        TextField {
            id: field
            width: parent.width
            height: 40
            placeholderText: "Buscar arquivos e pastas…"
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: Theme.fontSize + 2
            selectionColor: Theme.accent
            leftPadding: 40
            background: Rectangle {
                radius: 10
                color: Theme.pillBg
                Image {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: Theme.icon("system-search-symbolic", Theme.textDim)
                }
            }
            onTextEdited: debounce.restart()
            Keys.onDownPressed: root.current = Math.min(root.current + 1, finder.results.length - 1)
            Keys.onUpPressed: root.current = Math.max(root.current - 1, 0)
            Keys.onReturnPressed: e => root.activate(root.current, e.modifiers & Qt.ShiftModifier)
            Keys.onEnterPressed: e => root.activate(root.current, e.modifiers & Qt.ShiftModifier)
        }

        Text {
            visible: !finder.searching && finder.results.length === 0
            width: parent.width
            topPadding: 10; bottomPadding: 10
            horizontalAlignment: Text.AlignHCenter
            text: field.text.trim() ? "Nada encontrado" : "Nenhum arquivo recente"
            color: Theme.textFaint
            font.pixelSize: 12
        }

        Text {
            visible: finder.results.length > 0 && field.text.trim() === ""
            leftPadding: 8
            text: "Recentes"
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 360)
            clip: true
            model: finder.results
            currentIndex: root.current
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 40
                radius: 8
                color: index === root.current ? Theme.selected : rowArea.containsMouse ? Theme.hover : "transparent"

                Item {
                    id: ic
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24
                    FolderIcon { visible: row.modelData.isDir; anchors.fill: parent }
                    Image {
                        visible: !row.modelData.isDir
                        anchors.fill: parent
                        sourceSize: Qt.size(48, 48)
                        asynchronous: true
                        source: row.modelData.isDir ? ""
                              : Settings.fileIcons === "system" ? Theme.icon(row.modelData.icon) + "&pack=0"
                              : Theme.fileIcon(row.modelData.icon, row.modelData.name)
                    }
                }
                Column {
                    anchors { left: ic.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        color: Theme.text
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.location
                        color: Theme.textFaint
                        font.pixelSize: 11
                        elide: Text.ElideLeft
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: e => root.activate(row.index, e.modifiers & Qt.ShiftModifier)
                }
            }
        }

        Text {
            width: parent.width
            rightPadding: 6
            horizontalAlignment: Text.AlignRight
            text: finder.searching ? "Procurando…" : "Enter abre · Shift+Enter mostra na pasta"
            color: Theme.textFaint
            font.pixelSize: 11
        }
    }
}
