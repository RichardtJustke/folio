import QtQuick
import QtQuick.Controls
import Folio

// Painel de prévia à direita (F3): mostra o item selecionado (imagem, texto, miniatura ou ícone)
// e os detalhes; sem seleção, a pasta atual; com vários, a contagem e o tamanho somado.
Rectangle {
    id: root

    required property FileOps ops
    required property FileModel fileModel

    // reavalia ao mudar a seleção ou a listagem
    // (as comparações com >= 0 só existem para criar a dependência)
    readonly property var selected: fileModel.selectionRevision >= 0 && fileModel.revision >= 0 ? fileModel.selectedPaths() : []
    readonly property var entry: {
        if (selected.length !== 1) return null
        const e = fileModel.entry(fileModel.currentIndex)
        return e && e.path === selected[0] ? e : null
    }
    readonly property var info: {
        const p = entry ? entry.path : selected.length === 0 && !fileModel.isSearch && !fileModel.isTrash ? fileModel.path : ""
        return p ? ops.properties(p) : null
    }
    readonly property real totalSize: {
        if (selected.length < 2) return 0
        let sum = 0
        for (const p of selected.slice(0, 500)) { const i = ops.properties(p); if (!i.isDir) sum += i.size }
        return sum
    }

    radius: Theme.radius - 4
    color: Theme.subtle
    border.width: 1
    border.color: Theme.border
    clip: true

    signal openRequested(var entry)
    signal quickLookRequested
    signal propertiesRequested(var paths)

    // "rw-r-----" por extenso: quem pode o quê
    function accessLabel(mode) {
        const lvl = (r, w) => r && w ? "leitura e escrita" : r ? "só leitura" : w ? "só escrita" : "sem acesso"
        const owner = lvl(mode & 0o400, mode & 0o200)
        const group = lvl(mode & 0o40, mode & 0o20)
        const other = lvl(mode & 0o4, mode & 0o2)
        if (!(mode & 0o66)) return "Só " + root.info.owner + ": " + owner
        return root.info.owner + ": " + owner + "\nGrupo " + root.info.group + ": " + group + "\nOutros: " + other
    }
    readonly property string appName: info && !info.isDir ? ops.defaultAppName(info.mime) : ""

    // linha de um cartão: ícone, rótulo pequeno e valor
    component InfoRow: Item {
        property string icon
        property string label
        property string value
        visible: value !== ""
        width: parent ? parent.width : 0
        height: visible ? texts.height + 12 : 0
        Rectangle { visible: parent.y > 0; width: parent.width; height: 1; color: Theme.border }
        Image {
            x: 0; y: 9
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: Theme.icon(parent.icon, Theme.textFaint)
        }
        Column {
            id: texts
            x: 23; y: 6
            width: parent.width - 23
            spacing: 1
            Text { text: parent.parent.label; color: Theme.textFaint; font.pixelSize: 10 }
            Text {
                width: parent.width
                text: parent.parent.value
                color: Theme.text
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 4
                elide: Text.ElideMiddle
            }
        }
    }
    component InfoCard: Rectangle {
        default property alias rows: rowsCol.data
        visible: rowsCol.height > 0
        width: parent ? parent.width : 0
        height: rowsCol.height + 4
        radius: 10
        color: Theme.overlay(Theme.light ? 0.04 : 0.045)
        Column { id: rowsCol; x: 10; y: 2; width: parent.width - 20 }
    }
    component QuickButton: Rectangle {
        property string icon
        property string tip
        signal clicked
        width: 34; height: 30; radius: 8
        color: qbArea.containsMouse ? Theme.buttonHover : Theme.buttonBg
        Image {
            anchors.centerIn: parent
            width: 15; height: 15
            sourceSize: Qt.size(30, 30)
            source: Theme.icon(parent.icon, Theme.text)
        }
        MouseArea { id: qbArea; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
        ToolTip.visible: qbArea.containsMouse
        ToolTip.delay: 500
        ToolTip.text: tip
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentHeight: col.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: parent.width
            spacing: 12

            Item { // prévia
                width: parent.width
                height: Math.round(width * 0.66)
                Loader {
                    anchors.fill: parent
                    sourceComponent: {
                        if (root.selected.length > 1) return manyComp
                        if (!root.entry) return root.info ? folderComp : null
                        if (root.entry.isDir) return folderComp
                        switch (root.entry.preview) {
                        case "image": return imageComp
                        case "text": return textComp
                        case "thumb": return thumbComp
                        default: return iconComp
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.selected.length > 1 ? root.selected.length + " itens selecionados"
                        : root.info ? root.info.name : ""
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.DemiBold
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideMiddle
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.selected.length > 1 ? Theme.sizeLabel(root.totalSize) + " em arquivos"
                        : root.info && root.info.type ? root.info.type[0].toUpperCase() + root.info.type.slice(1) : ""
                    color: Theme.textDim
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row { // ações rápidas
                visible: root.info !== null || root.selected.length > 1
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                QuickButton {
                    visible: root.entry !== null
                    icon: "document-open-symbolic"
                    tip: "Abrir"
                    onClicked: root.openRequested(root.entry)
                }
                QuickButton {
                    visible: root.entry !== null
                    icon: "view-reveal-symbolic"
                    tip: "Visualização Rápida (Espaço)"
                    onClicked: root.quickLookRequested()
                }
                QuickButton {
                    icon: "edit-copy-symbolic"
                    tip: "Copiar caminho"
                    onClicked: root.ops.copyText(root.selected.length ? root.selected.join("\n") : root.info.path)
                }
                QuickButton {
                    icon: "document-properties-symbolic"
                    tip: "Propriedades (Alt+Enter)"
                    onClicked: root.propertiesRequested(root.selected.length ? root.selected : [root.info.path])
                }
            }

            InfoCard {
                visible: root.selected.length <= 1 && root.info !== null
                InfoRow {
                    icon: "drive-harddisk-symbolic"
                    label: root.info && root.info.isDir ? "Itens" : "Tamanho"
                    value: !root.info ? ""
                         : root.info.isDir ? (root.entry ? Theme.itemsLabel(root.entry.itemCount) : Theme.itemsLabel(root.fileModel.count))
                         : Theme.sizeLabel(root.info.size)
                }
                InfoRow { icon: "folder-symbolic"; label: "Onde"; value: root.info ? root.info.location : "" }
                InfoRow { icon: "emblem-symbolic-link"; label: "Aponta para"; value: root.info && root.info.isSymlink ? root.info.target : "" }
                InfoRow { icon: "application-x-executable-symbolic"; label: "Abre com"; value: root.appName }
            }

            InfoCard {
                visible: root.selected.length <= 1 && root.info !== null
                InfoRow {
                    icon: "x-office-calendar-symbolic"
                    label: "Criado"
                    value: root.info && root.info.created && !isNaN(root.info.created) ? Theme.dateLabel(root.info.created) : ""
                }
                InfoRow { icon: "document-edit-symbolic"; label: "Modificado"; value: root.info ? Theme.dateLabel(root.info.modified) : "" }
                InfoRow {
                    icon: "document-open-recent-symbolic"
                    label: "Acessado"
                    value: root.info && root.info.accessed && !isNaN(root.info.accessed) ? Theme.dateLabel(root.info.accessed) : ""
                }
            }

            InfoCard {
                visible: root.selected.length <= 1 && root.info !== null
                InfoRow {
                    icon: "changes-prevent-symbolic"
                    label: "Acesso"
                    value: root.info ? root.accessLabel(root.info.mode) : ""
                }
                InfoRow {
                    icon: "tag-symbolic"
                    label: "Etiquetas"
                    value: root.entry && root.entry.tags ? root.entry.tags.join(", ") : ""
                }
            }
        }
    }

    Component {
        id: imageComp
        Image {
            source: root.entry ? root.ops.fileUrl(root.entry.path) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            autoTransform: true
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
        }
    }
    Component {
        id: thumbComp
        Image {
            source: root.entry ? "image://thumb/" + root.entry.thumb : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(256, 256)
            smooth: true
        }
    }
    Component {
        id: textComp
        Rectangle {
            radius: 10
            color: Theme.overlay(0.05)
            clip: true
            Text {
                anchors.fill: parent
                anchors.margins: 8
                text: root.entry ? root.ops.readText(root.entry.path, 4096) : ""
                color: Theme.textDim
                font.family: "monospace"
                font.pixelSize: 10
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                clip: true
            }
        }
    }
    Component {
        id: iconComp
        Item {
            Image {
                anchors.centerIn: parent
                width: 112; height: 112
                sourceSize: Qt.size(224, 224)
                source: !root.entry ? ""
                      : Settings.fileIcons === "system" ? Theme.icon(root.entry.icon) + "&pack=0"
                      : Theme.fileIcon(root.entry.icon, root.entry.name)
            }
        }
    }
    Component {
        id: folderComp
        Item {
            FolderIcon {
                anchors.centerIn: parent
                width: 128; height: 128
                glyph: root.entry ? (root.entry.glyph || "") : ""
            }
        }
    }
    Component {
        id: manyComp
        Item { // um ícone com a contagem
            Image {
                id: manyIcon
                anchors.centerIn: parent
                width: 112; height: 112
                sourceSize: Qt.size(224, 224)
                source: Settings.fileIcons === "system" ? Theme.icon("text-x-generic") + "&pack=0"
                      : Theme.fileIcon("text-x-generic", "")
            }
            Rectangle {
                anchors { right: manyIcon.right; top: manyIcon.top; margins: -6 }
                width: Math.max(28, countText.implicitWidth + 14); height: 28; radius: 14
                color: Theme.accent
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.selected.length
                    color: Theme.accentText
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }
        }
    }
}
