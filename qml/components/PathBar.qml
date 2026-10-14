import QtQuick
import QtQuick.Controls
import Folio

// Caminho em segmentos clicáveis; clique no vazio (ou Ctrl+L) vira um campo editável,
// com sugestões de pastas (↑/↓ escolhem, Tab completa).
Item {
    id: root

    required property string path
    required property string title
    required property bool special // lixeira / busca: mostra só o título
    required property FileOps ops
    property bool editing: false

    signal navigate(string path)
    signal submitted(string typed)
    signal closed

    function edit() {
        if (special) return
        editing = true
        field.text = root.path === Settings.home ? "~/" : root.path.startsWith(Settings.home + "/")
                   ? "~" + root.path.slice(Settings.home.length) + "/" : root.path + (root.path === "/" ? "" : "/")
        field.forceActiveFocus()
        field.selectAll()
    }

    // ── sugestões ──
    property var suggestions: []
    property int suggestion: -1
    function refreshSuggestions() {
        suggestions = editing ? ops.completions(field.text) : []
        suggestion = -1
    }
    // Tab: com uma sugestão escolhida usa ela; senão completa o prefixo comum de todas
    function complete() {
        if (suggestions.length === 0) return
        let t = suggestion >= 0 ? suggestions[suggestion] : suggestions[0]
        if (suggestion < 0) {
            for (const s of suggestions) {
                let i = 0
                while (i < t.length && i < s.length && t[i].toLowerCase() === s[i].toLowerCase()) i++
                t = t.slice(0, i)
            }
            if (t.length <= field.text.length) { suggestion = 0; return } // nada a completar: destaca a 1ª
        }
        field.text = t
        field.cursorPosition = t.length
    }

    readonly property var segments: {
        const home = Settings.home
        const out = []
        let p = root.path
        let acc = ""
        if (home && (p === home || p.startsWith(home + "/"))) {
            out.push({ name: "Início", path: home })
            acc = home
            p = p.slice(home.length)
        } else {
            out.push({ name: "/", path: "/" })
        }
        for (const part of p.split("/")) {
            if (!part) continue
            acc = (acc === "/" ? "" : acc) + "/" + part
            out.push({ name: part, path: acc })
        }
        return out
    }

    clip: true
    implicitHeight: 28

    Row {
        id: crumbs
        visible: !root.editing && !root.special
        x: Math.min(0, root.width - width)
        height: parent.height
        spacing: 0

        Repeater {
            model: root.segments
            delegate: Row {
                required property var modelData
                required property int index
                height: crumbs.height
                Text {
                    visible: index > 1 || (index === 1 && modelData.path !== "/")
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSize + 1
                    leftPadding: 2; rightPadding: 2
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: label.implicitWidth + 12; height: 24; radius: 12
                    color: segArea.containsMouse ? Theme.hover : "transparent"
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.name
                        color: index === root.segments.length - 1 ? Theme.text : Theme.textDim
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: index === root.segments.length - 1 ? Font.Bold : Font.Normal
                    }
                    MouseArea {
                        id: segArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.navigate(modelData.path)
                    }
                }
            }
        }
    }

    Text {
        visible: root.special && !root.editing
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.text
        font.pixelSize: Theme.fontSize + 2
        font.weight: Font.Bold
        elide: Text.ElideRight
        width: parent.width
    }

    // clique no espaço livre
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !root.editing
        onDoubleClicked: root.edit()
        onClicked: root.edit()
    }

    TextField {
        id: field
        visible: root.editing
        anchors.fill: parent
        color: Theme.text
        font.pixelSize: Theme.fontSize
        selectionColor: Theme.accent
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: 12
        background: Rectangle { radius: height / 2; color: Theme.pillBg; border.width: 1; border.color: Theme.accent }
        onAccepted: {
            const t = root.suggestion >= 0 ? root.suggestions[root.suggestion] : text
            root.editing = false; root.submitted(t); root.closed()
        }
        onTextEdited: root.refreshSuggestions()
        Keys.onTabPressed: root.complete()
        Keys.onDownPressed: if (root.suggestions.length) root.suggestion = (root.suggestion + 1) % root.suggestions.length
        Keys.onUpPressed: if (root.suggestions.length) root.suggestion = root.suggestion <= 0 ? root.suggestions.length - 1 : root.suggestion - 1
        Keys.onEscapePressed: {
            if (root.suggestions.length) { root.suggestions = []; return }
            root.editing = false; root.closed()
        }
        onActiveFocusChanged: if (!activeFocus && root.editing) { root.editing = false; root.closed() }
    }

    Popup {
        id: suggestPopup
        y: root.height + 6
        width: root.width
        padding: 4
        visible: root.editing && root.suggestions.length > 0
        closePolicy: Popup.NoAutoClose
        focus: false
        background: Rectangle { radius: 12; color: Theme.light ? Qt.rgba(0.98, 0.98, 0.99, 0.97) : Qt.rgba(0.16, 0.16, 0.17, 0.96); border.width: 1; border.color: Theme.border }
        contentItem: Column {
            Repeater {
                model: root.suggestions
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: suggestPopup.width - 8; height: 28; radius: 8
                    color: index === root.suggestion ? Theme.selected : sArea.containsMouse ? Theme.hover : "transparent"
                    Text {
                        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData
                        color: Theme.text
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideLeft
                    }
                    MouseArea {
                        id: sArea
                        anchors.fill: parent
                        hoverEnabled: true
                        // pressionar não tira o foco do campo; o clique entra na pasta
                        onPressed: e => e.accepted = true
                        onClicked: { root.editing = false; root.submitted(modelData); root.closed() }
                    }
                }
            }
        }
    }
}
