import QtQuick
import Folio

// Pergunta o que fazer quando o destino já tem um item com o mesmo nome.
GlassPopup {
    id: root

    required property FileOps ops

    property string name
    property string destDir
    property bool isDir
    property bool applyAll: false
    property bool answered: false

    function ask(name, destDir, isDir) {
        root.name = name
        root.destDir = destDir
        root.isDir = isDir
        answered = false
        open()
    }

    function answer(choice) {
        answered = true
        ops.resolveConflict(choice, applyAll)
        close()
    }

    onClosed: if (!answered) ops.resolveConflict(FileOps.Skip, false) // Esc = pular

    Connections {
        target: root.ops
        function onBusyChanged() {
            if (root.ops.busy) return
            root.applyAll = false
            root.answered = true
            root.close()
        }
    }

    width: 440

    contentItem: Column {
        spacing: 10

        Text {
            width: parent.width
            text: "Já existe " + (root.isDir ? "uma pasta" : "um arquivo") + " chamado “" + root.name + "”."
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: "Em " + root.destDir + ". Substituir move o item existente para a Lixeira."
            color: Theme.textDim
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Item { // "aplicar a todos"
            width: applyRow.implicitWidth
            height: applyRow.implicitHeight
            Row {
                id: applyRow
                spacing: 8
                Rectangle {
                    width: 16; height: 16; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.applyAll ? Theme.accent : "transparent"
                    border.width: root.applyAll ? 0 : 1
                    border.color: Theme.borderStrong
                    Text { anchors.centerIn: parent; text: "✓"; visible: root.applyAll; color: "white"; font.pixelSize: 11 }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Aplicar a todos"; color: Theme.text; font.pixelSize: 12 }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.applyAll = !root.applyAll
            }
        }
        Item { width: 1; height: 4 }
        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton { text: "Pular"; onClicked: root.answer(FileOps.Skip) }
            DialogButton { text: "Manter Ambos"; onClicked: root.answer(FileOps.KeepBoth) }
            DialogButton { text: "Substituir"; primary: true; onClicked: root.answer(FileOps.Replace) }
        }
    }
}
