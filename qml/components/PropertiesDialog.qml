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

    readonly property bool hashable: single && !info.isDir && !(paths[0] || "").includes("::")

    function show(list) {
        paths = list
        info = list.length === 1 ? ops.properties(list[0]) : ({})
        totalBytes = -1
        ops.computeSize(list)
        compareField.text = ""
        hasher.clear()
        // arquivos de até 200 MB: calcula sozinho; maiores esperam o botão
        if (hashable && info.size <= 200 * 1000 * 1000) hasher.compute(list[0])
        open()
    }
    onClosed: hasher.clear()

    Hasher { id: hasher }

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

        // ── Hashes ──
        Item { visible: root.hashable; width: parent.width; height: 6 }
        Item {
            visible: root.hashable
            width: parent.width
            height: 26
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Hashes"
                color: Theme.textDim
                font.pixelSize: 12
            }
            DialogButton {
                visible: !hasher.running && hasher.sha256 === ""
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "Calcular"
                onClicked: hasher.compute(root.paths[0])
            }
            Row {
                visible: hasher.running
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110; height: 4; radius: 2
                    color: Theme.pillBg
                    Rectangle { width: parent.width * hasher.progress; height: parent.height; radius: 2; color: Theme.accent }
                }
                Text { text: Math.round(hasher.progress * 100) + "%"; color: Theme.textFaint; font.pixelSize: 11 }
            }
        }
        Text {
            visible: root.hashable && hasher.error !== ""
            text: hasher.error
            color: Theme.danger
            font.pixelSize: 12
        }
        Repeater {
            model: root.hashable && hasher.sha256 !== "" ? [
                { label: "MD5", value: hasher.md5 },
                { label: "SHA-1", value: hasher.sha1 },
                { label: "SHA-256", value: hasher.sha256 }
            ] : []
            delegate: Item {
                id: hashRow
                required property var modelData
                readonly property bool hit: compareField.text.trim() !== "" && hasher.match(compareField.text) === modelData.label
                width: parent.width
                height: 24
                Text { anchors.verticalCenter: parent.verticalCenter; width: 70; text: hashRow.modelData.label; color: hashRow.hit ? Theme.accent : Theme.textDim; font.pixelSize: 11; font.weight: Font.DemiBold }
                Text {
                    anchors { left: parent.left; leftMargin: 74; right: copyBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: hashRow.modelData.value
                    color: Theme.text
                    font.pixelSize: 11
                    font.family: "monospace"
                    elide: Text.ElideMiddle
                }
                Rectangle {
                    id: copyBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; radius: 12
                    color: copyArea.containsMouse ? Theme.hover : "transparent"
                    Image {
                        anchors.centerIn: parent
                        width: 13; height: 13
                        sourceSize: Qt.size(26, 26)
                        source: Theme.icon("edit-copy-symbolic", Theme.textDim)
                    }
                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.text: "Copiar " + hashRow.modelData.label
                        ToolTip.delay: 400
                        onClicked: root.ops.copyText(hashRow.modelData.value)
                    }
                }
            }
        }
        TextField { // colar um hash para conferir
            id: compareField
            visible: root.hashable && hasher.sha256 !== ""
            width: parent.width
            placeholderText: "Cole um hash para comparar"
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: 11
            font.family: "monospace"
            selectionColor: Theme.accent
            rightPadding: 110
            background: Rectangle {
                radius: 8
                color: Theme.pillBg
                border.width: 1
                border.color: compareResult.visible ? (compareResult.ok ? "#30d158" : Theme.danger)
                            : compareField.activeFocus ? Theme.accent : Theme.border
            }
            Text {
                id: compareResult
                readonly property string which: hasher.match(compareField.text)
                readonly property bool ok: which !== ""
                visible: compareField.text.trim() !== ""
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: ok ? "✓ Confere (" + which + ")" : "✗ Não confere"
                color: ok ? "#30d158" : Theme.danger
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Item { width: 1; height: 4 }
        Row {
            anchors.right: parent.right
            DialogButton { text: "Fechar"; primary: true; onClicked: root.close() }
        }
    }
}
