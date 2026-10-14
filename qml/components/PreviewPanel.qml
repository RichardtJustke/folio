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

    Flickable {
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: parent.width
            spacing: 12

            Item { // prévia
                width: parent.width
                height: Math.min(width, 220)
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
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Rectangle { visible: details.visible; width: parent.width; height: 1; color: Theme.border }

            Column { // detalhes
                id: details
                visible: root.selected.length <= 1 && root.info !== null
                width: parent.width
                spacing: 8

                component Detail: Column {
                    property string label
                    property string value
                    visible: value !== ""
                    width: parent ? parent.width : 0
                    spacing: 1
                    Text { text: parent.label; color: Theme.textFaint; font.pixelSize: 11 }
                    Text {
                        width: parent.width
                        text: parent.value
                        color: Theme.text
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideMiddle
                    }
                }

                Detail {
                    label: root.info && root.info.isDir ? "Itens" : "Tamanho"
                    value: !root.info ? ""
                         : root.info.isDir ? (root.entry ? Theme.itemsLabel(root.entry.itemCount) : Theme.itemsLabel(root.fileModel.count))
                         : Theme.sizeLabel(root.info.size)
                }
                Detail { label: "Modificado"; value: root.info ? Theme.dateLabel(root.info.modified) : "" }
                Detail { label: "Criado"; value: root.info && root.info.created && !isNaN(root.info.created) ? Theme.dateLabel(root.info.created) : "" }
                Detail { label: "Local"; value: root.info ? root.info.location : "" }
                Detail { label: "Aponta para"; value: root.info && root.info.isSymlink ? root.info.target : "" }
                Detail { label: "Permissões"; value: root.info ? root.info.permString : "" }
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
            radius: 8
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
