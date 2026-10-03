import QtQuick
import QtQuick.Controls
import Folio

// Editor de nome inline: seleciona o nome sem a extensão, Enter confirma, Esc cancela.
TextField {
    id: root

    required property var entry
    signal committed(string newName)
    signal canceled

    property bool done: false

    font.pixelSize: 12
    color: Theme.text
    selectByMouse: true
    selectionColor: Theme.accent
    padding: 3
    background: Rectangle {
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.45)
        border.width: 1.5
        border.color: Theme.accent
    }

    function begin() {
        done = false
        text = entry.name
        forceActiveFocus()
        const dot = entry.isDir ? -1 : text.lastIndexOf(".")
        select(0, dot > 0 ? dot : text.length)
    }

    function finish(commit) {
        if (done) return
        done = true
        commit ? committed(text) : canceled()
    }

    onVisibleChanged: if (visible) begin()
    Component.onCompleted: if (visible) begin()
    onAccepted: finish(true)
    onActiveFocusChanged: if (!activeFocus && visible) finish(true)
    Keys.onEscapePressed: finish(false)
}
