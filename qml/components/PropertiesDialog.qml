import QtQuick
import QtQuick.Controls
import Folio

// Propriedades (Alt+Enter): metadados, tamanho calculado em segundo plano e permissões.
GlassPopup {
    id: root

    required property FileOps ops
    property var paths: []
    property var info: ({})
    property real totalBytes: -1
    property int fileCount: 0
    property int folderCount: 0
    readonly property bool single: paths.length === 1
    readonly property int perm: info.mode ?? 0

    width: Math.min(440, Overlay.overlay ? Overlay.overlay.width - 40 : 440)

    function show(list) {
        paths = list
        info = list.length === 1 ? ops.properties(list[0]) : ({})
        totalBytes = -1
        ops.computeSize(list)
        open()
    }

    function toggle(bit) {
        const next = root.perm ^ bit
        if (ops.setPermissions(paths[0], next))
            info = ops.properties(paths[0])
    }

    Connections {
        target: root.ops
        function onSizeComputed(bytes, files, folders) {
            root.totalBytes = bytes
            root.fileCount = files
            root.folderCount = folders
        }
    }

    component Row2: Item {
        property string label
        property string value
        width: parent.width
        height: Math.max(20, v.implicitHeight)
        Text { width: 110; text: parent.label; color: Theme.textDim; font.pixelSize: 12 }
        Text {
            id: v
            x: 120; width: parent.width - 120
            text: parent.value
            color: Theme.text
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
        }
    }

    component PermBox: Rectangle {
        property int bit
        property bool editable: true
        width: 26; height: 26; radius: 6
        color: (root.perm & bit) ? Theme.accent : Theme.pillBg
        border.width: 1; border.color: Theme.border
        Text { anchors.centerIn: parent; visible: root.perm & parent.bit; text: "✓"; color: "white"; font.pixelSize: 12 }
        MouseArea { anchors.fill: parent; enabled: parent.editable; onClicked: root.toggle(parent.bit) }
    }

    contentItem: Column {
        spacing: 8

        Row {
            spacing: 12
            Image {
                visible: root.single
                width: 40; height: 40
                sourceSize: Qt.size(80, 80)
                source: root.single ? (root.info.isDir ? Theme.folderSvg : Theme.icon("text-x-generic")) : ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.width - 100
                text: root.single ? root.info.name : root.paths.length + " itens selecionados"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
                elide: Text.ElideMiddle
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Row2 { visible: root.single; label: "Tipo"; value: root.info.type ?? "" }
        Row2 { visible: root.single; label: "Local"; value: root.info.location ?? "" }
        Row2 { visible: root.single && root.info.isSymlink; label: "Aponta para"; value: root.info.target ?? "" }
        Row2 {
            label: "Tamanho"
            value: root.totalBytes < 0 ? "Calculando…"
                 : Theme.sizeLabel(root.totalBytes) + (root.folderCount + root.fileCount > 1
                       ? " — " + root.fileCount + " arquivos, " + root.folderCount + " pastas" : "")
        }
        Row2 { visible: root.single; label: "Modificado"; value: root.single ? Theme.dateLabel(root.info.modified) : "" }
        Row2 { visible: root.single; label: "Acessado"; value: root.single ? Theme.dateLabel(root.info.accessed) : "" }
        Row2 { visible: root.single; label: "Dono"; value: root.single ? root.info.owner + " : " + root.info.group : "" }

        Item {
            visible: root.single
            width: parent.width; height: 6
        }
        Text {
            visible: root.single
            text: "Permissões"
            color: Theme.textDim
            font.pixelSize: 12
        }
        Grid {
            visible: root.single
            columns: 4
            columnSpacing: 10
            rowSpacing: 6
            Item { width: 70; height: 18 }
            Text { text: "Ler"; color: Theme.textDim; font.pixelSize: 11; width: 26; horizontalAlignment: Text.AlignHCenter }
            Text { text: "Escrever"; color: Theme.textDim; font.pixelSize: 11; width: 26; horizontalAlignment: Text.AlignHCenter }
            Text { text: "Executar"; color: Theme.textDim; font.pixelSize: 11; width: 26; horizontalAlignment: Text.AlignHCenter }

            Text { text: "Dono"; color: Theme.text; font.pixelSize: 12; width: 70; height: 26; verticalAlignment: Text.AlignVCenter }
            PermBox { bit: 0400 }
            PermBox { bit: 0200 }
            PermBox { bit: 0100 }
            Text { text: "Grupo"; color: Theme.text; font.pixelSize: 12; width: 70; height: 26; verticalAlignment: Text.AlignVCenter }
            PermBox { bit: 040 }
            PermBox { bit: 020 }
            PermBox { bit: 010 }
            Text { text: "Outros"; color: Theme.text; font.pixelSize: 12; width: 70; height: 26; verticalAlignment: Text.AlignVCenter }
            PermBox { bit: 04 }
            PermBox { bit: 02 }
            PermBox { bit: 01 }
        }

        Item { width: 1; height: 4 }
        Row {
            anchors.right: parent.right
            DialogButton { text: "Fechar"; primary: true; onClicked: root.close() }
        }
    }
}
