import QtQuick
import QtQuick.Controls
import Folio

// Caminho em segmentos clicáveis; clique no vazio (ou Ctrl+L) vira um campo editável.
Item {
    id: root

    required property string path
    required property string title
    required property bool special // lixeira / busca: mostra só o título
    property bool editing: false

    signal navigate(string path)
    signal submitted(string typed)
    signal closed

    function edit() {
        if (special) return
        editing = true
        field.text = root.path
        field.forceActiveFocus()
        field.selectAll()
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
        onAccepted: { root.editing = false; root.submitted(text); root.closed() }
        Keys.onEscapePressed: { root.editing = false; root.closed() }
        onActiveFocusChanged: if (!activeFocus && root.editing) { root.editing = false; root.closed() }
    }
}
