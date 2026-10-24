import QtQuick
import QtQuick.Controls
import Folio

// Paleta de comandos (Ctrl+Shift+P): procura qualquer ação ou configuração pelo nome.
// ↑/↓ escolhem; Enter executa. Itens indisponíveis agora (ex.: Colar na Lixeira) ficam esmaecidos.
Popup {
    id: root

    property var actions: []        // as ações do Main.qml
    property var keysFor: a => a.keys
    property var extra: []          // comandos de configurações: { id, label, group, run }

    property int current: 0
    property var used: []           // ids usados nesta sessão, mais recente primeiro

    readonly property var everything: actions.concat(extra)
    function plain(t) { return t.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase() }
    readonly property var results: {
        const words = plain(field.text).split(/\s+/).filter(w => w)
        const hit = everything.filter(c => {
            const hay = plain(c.label + " " + c.group)
            return words.every(w => hay.includes(w))
        })
        // usados por último primeiro; depois o nome com todas as palavras (começando pela 1ª antes), depois só o grupo
        const rank = c => {
            const u = used.indexOf(c.id)
            if (u >= 0) return u
            if (!words.length) return 200
            const name = plain(c.label)
            const all = words.every(w => name.includes(w))
            const starts = name.startsWith(words[0])
            return all && starts ? 100 : all ? 120 : starts ? 140 : 200
        }
        return hit.map((c, i) => ({ c, i })).sort((a, b) => rank(a.c) - rank(b.c) || a.i - b.i).map(x => x.c)
    }
    onResultsChanged: current = 0

    function show() {
        field.text = ""
        current = 0
        open()
        field.forceActiveFocus()
    }

    function available(c) { return !c.when || c.when() }

    function activate(i) {
        const c = results[i]
        if (!c || !available(c)) return
        used = [c.id].concat(used.filter(id => id !== c.id)).slice(0, 8)
        close()
        Qt.callLater(c.run)
    }

    function keyLabel(c) {
        if (!c.keys) return ""
        const k = keysFor(c)
        return k.length ? k[0] : ""
    }

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round(parent.height * 0.14)
    width: Math.min(560, parent.width - 40)
    padding: 8
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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
            placeholderText: "Digite um comando ou configuração…"
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
                    source: Theme.icon("utilities-terminal-symbolic,system-run-symbolic,open-menu-symbolic", Theme.textDim)
                }
            }
            Keys.onDownPressed: root.current = Math.min(root.current + 1, root.results.length - 1)
            Keys.onUpPressed: root.current = Math.max(root.current - 1, 0)
            Keys.onReturnPressed: root.activate(root.current)
            Keys.onEnterPressed: root.activate(root.current)
        }

        Text {
            visible: root.results.length === 0
            width: parent.width
            topPadding: 10; bottomPadding: 10
            horizontalAlignment: Text.AlignHCenter
            text: "Nenhum comando encontrado"
            color: Theme.textFaint
            font.pixelSize: 12
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 380)
            clip: true
            model: root.results
            currentIndex: root.current
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool ok: root.available(modelData)
                width: ListView.view.width
                height: 36
                radius: 8
                color: index === root.current ? Theme.selected : rowArea.containsMouse ? Theme.hover : "transparent"
                opacity: ok ? 1 : 0.45

                Text {
                    id: label
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: Math.min(implicitWidth, parent.width - group.width - keys.width - 48)
                    text: row.modelData.label
                    color: Theme.text
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
                Text {
                    id: group
                    anchors { left: label.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: row.modelData.group
                    color: Theme.textFaint
                    font.pixelSize: 11
                }
                Rectangle {
                    id: keys
                    readonly property string k: root.keyLabel(row.modelData)
                    visible: k !== ""
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: visible ? keyText.implicitWidth + 12 : 0; height: 20; radius: 5
                    color: Theme.pillBg
                    border.width: 1; border.color: Theme.border
                    Text { id: keyText; anchors.centerIn: parent; text: keys.k; color: Theme.textDim; font.pixelSize: 10 }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.activate(row.index)
                }
            }
        }

        Text {
            width: parent.width
            rightPadding: 6
            horizontalAlignment: Text.AlignRight
            text: "Enter executa · Esc fecha"
            color: Theme.textFaint
            font.pixelSize: 11
        }
    }
}
