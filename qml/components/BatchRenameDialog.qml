import QtQuick
import QtQuick.Controls
import Folio

// Renomear vários itens: substituir texto, adicionar antes/depois do nome, numerar,
// regex ou mudança de caixa. A extensão é preservada; a prévia mostra os primeiros resultados.
GlassPopup {
    id: root

    required property FileOps ops
    property var paths: []
    property string mode: "replace" // replace | add | format | regex | case

    width: Math.min(500, Overlay.overlay ? Overlay.overlay.width - 40 : 500)

    function show(list) {
        paths = list
        mode = "replace"
        findField.text = ""
        replaceField.text = ""
        addField.text = ""
        addAfter = true
        baseField.text = ""
        startField.text = "1"
        regexField.text = ""
        regexReplaceField.text = ""
        caseMode = "lower"
        open()
        findField.forceActiveFocus()
    }

    property bool addAfter: true
    property string caseMode: "lower" // lower | upper | title

    function split(name) { // ["foto", ".jpg"]; pastas e ".ocultos" ficam sem extensão
        const dot = name.lastIndexOf(".")
        return dot > 0 ? [name.slice(0, dot), name.slice(dot)] : [name, ""]
    }

    function applyCase(stem) {
        if (caseMode === "upper") return stem.toUpperCase()
        if (caseMode === "title") return stem.replace(/\w\S*/g, w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        return stem.toLowerCase()
    }

    function newName(path, i) {
        const name = path.split("/").pop()
        const [stem, ext] = split(name)
        if (mode === "replace")
            return findField.text ? stem.split(findField.text).join(replaceField.text) + ext : name
        if (mode === "add")
            return addAfter ? stem + addField.text + ext : addField.text + stem + ext
        if (mode === "regex") {
            if (!regexField.text) return name
            try {
                const re = new RegExp(regexField.text, "g")
                return stem.replace(re, regexReplaceField.text) + ext
            } catch (e) { return name }
        }
        if (mode === "case")
            return applyCase(stem) + ext
        const start = parseInt(startField.text) || 0
        const digits = String(start + paths.length - 1).length
        const n = String(start + i).padStart(Math.max(2, digits), "0")
        return (baseField.text || "Item") + " " + n + ext
    }

    readonly property var results: {
        // dependências explícitas dos campos
        const deps = [mode, findField.text, replaceField.text, addField.text, addAfter,
                      baseField.text, startField.text, regexField.text, regexReplaceField.text, caseMode]
        return deps && paths.map((p, i) => newName(p, i))
    }
    readonly property int changedCount: results.filter((n, i) => n !== paths[i].split("/").pop()).length
    readonly property bool regexValid: {
        if (mode !== "regex" || !regexField.text) return true
        try { new RegExp(regexField.text); return true } catch (e) { return false }
    }

    function accept() {
        if (changedCount === 0) { close(); return }
        if (ops.renameMany(paths, results) > 0) close()
    }

    component ModeButton: Rectangle {
        property string value
        property string label
        width: t.implicitWidth + 20; height: 24; radius: 12
        color: root.mode === value ? Theme.accent : "transparent"
        Text {
            id: t
            anchors.centerIn: parent
            text: parent.label
            color: root.mode === parent.value ? "white" : Theme.text
            font.pixelSize: 12
        }
        MouseArea { anchors.fill: parent; onClicked: root.mode = parent.value }
    }

    component Choice: Rectangle {
        property string label
        property bool on
        signal picked
        width: ct.implicitWidth + 20; height: 26; radius: 13
        color: on ? Theme.selected : area.containsMouse ? Theme.hover : "transparent"
        border.width: 1; border.color: on ? Theme.borderStrong : Theme.border
        Text { id: ct; anchors.centerIn: parent; text: parent.label; color: Theme.text; font.pixelSize: 12 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: parent.picked() }
    }

    component Field: TextField {
        color: Theme.text
        font.pixelSize: Theme.fontSize
        selectionColor: Theme.accent
        placeholderTextColor: Theme.textFaint
        leftPadding: 12
        background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: parent.activeFocus ? Theme.accent : Theme.border }
        onAccepted: root.accept()
    }

    contentItem: Column {
        spacing: 12

        Text {
            width: parent.width
            text: "Renomear " + root.paths.length + " itens"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Rectangle { // modos
            width: modes.width + 4; height: 28; radius: 14
            color: Theme.pillBg
            border.width: 1; border.color: Theme.border
            Row {
                id: modes
                x: 2; y: 2
                spacing: 0
                ModeButton { value: "replace"; label: "Substituir" }
                ModeButton { value: "add"; label: "Adicionar" }
                ModeButton { value: "format"; label: "Numerar" }
                ModeButton { value: "regex"; label: "Regex" }
                ModeButton { value: "case"; label: "Caixa" }
            }
        }

        Column {
            visible: root.mode === "replace"
            width: parent.width
            spacing: 8
            Field { id: findField; width: parent.width; placeholderText: "Procurar" }
            Field { id: replaceField; width: parent.width; placeholderText: "Substituir por (vazio = apagar)" }
        }

        Column {
            visible: root.mode === "add"
            width: parent.width
            spacing: 8
            Field { id: addField; width: parent.width; placeholderText: "Texto" }
            Row {
                spacing: 6
                Choice { label: "Antes do nome"; on: !root.addAfter; onPicked: root.addAfter = false }
                Choice { label: "Depois do nome"; on: root.addAfter; onPicked: root.addAfter = true }
            }
        }

        Row {
            visible: root.mode === "format"
            width: parent.width
            spacing: 8
            Field { id: baseField; width: parent.width - 98; placeholderText: "Nome (ex.: Viagem)" }
            Field {
                id: startField
                width: 90
                placeholderText: "Início"
                validator: IntValidator { bottom: 0; top: 999999 }
                inputMethodHints: Qt.ImhDigitsOnly
            }
        }

        Column {
            visible: root.mode === "regex"
            width: parent.width
            spacing: 8
            Field {
                id: regexField
                width: parent.width
                placeholderText: "Padrão regex (ex.: IMG_(\\d+))"
                font.family: "monospace"
                color: root.regexValid ? Theme.text : Theme.danger
            }
            Field { id: regexReplaceField; width: parent.width; placeholderText: "Substituir por (use $1, $2…)" }
            Text {
                visible: !root.regexValid
                width: parent.width
                text: "⚠ Padrão regex inválido"
                color: Theme.danger
                font.pixelSize: 11
            }
        }

        Column {
            visible: root.mode === "case"
            width: parent.width
            spacing: 8
            Row {
                spacing: 6
                Choice { label: "minúsculas"; on: root.caseMode === "lower"; onPicked: root.caseMode = "lower" }
                Choice { label: "MAIÚSCULAS"; on: root.caseMode === "upper"; onPicked: root.caseMode = "upper" }
                Choice { label: "Title Case"; on: root.caseMode === "title"; onPicked: root.caseMode = "title" }
            }
        }

        Rectangle { // prévia
            width: parent.width
            height: Math.min(root.paths.length, 6) * 22 + 12
            radius: 8
            color: Theme.overlay(0.04)
            Column {
                anchors { fill: parent; margins: 6 }
                Repeater {
                    model: Math.min(root.paths.length, 6)
                    delegate: Row {
                        required property int index
                        width: parent.width
                        height: 22
                        spacing: 6
                        readonly property string oldName: root.paths[index].split("/").pop()
                        readonly property string nextName: root.results[index] ?? ""
                        Text {
                            width: (parent.width - 24) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.oldName
                            color: Theme.textDim
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "→"; color: Theme.textFaint; font.pixelSize: 12 }
                        Text {
                            width: (parent.width - 24) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.nextName
                            color: parent.nextName !== parent.oldName ? Theme.text : Theme.textFaint
                            font.pixelSize: 12
                            font.weight: parent.nextName !== parent.oldName ? Font.DemiBold : Font.Normal
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }
        Text {
            visible: root.paths.length > 6
            text: "e mais " + (root.paths.length - 6) + "…"
            color: Theme.textFaint
            font.pixelSize: 11
        }

        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton { text: "Cancelar"; onClicked: root.close() }
            DialogButton {
                text: root.changedCount ? "Renomear " + root.changedCount : "Renomear"
                primary: true
                enabled: root.changedCount > 0 && root.regexValid
                onClicked: root.accept()
            }
        }
    }
}