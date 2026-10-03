import QtQuick
import QtQuick.Controls
import Folio

// Visualização rápida (Espaço): imagem, texto, miniatura ou ícone + metadados.
// Não rouba o foco: as setas continuam navegando na vista e o preview acompanha.
Item {
    id: root

    required property FileOps ops
    property var entry: ({})
    property bool shown: false

    readonly property bool hasEntry: entry !== undefined && entry.path !== undefined

    anchors.fill: parent
    visible: opacity > 0
    opacity: shown && hasEntry ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: root.shown = false; onWheel: w => w.accepted = true }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.75, 960)
        height: Math.min(parent.height * 0.82, 720)
        radius: 14
        color: Theme.menuBg
        border.width: 1
        border.color: Theme.borderStrong
        scale: root.shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent } // não fecha ao clicar no painel

        Text {
            id: titleText
            anchors { left: parent.left; right: closeBtn.left; top: parent.top; margins: 14 }
            text: root.hasEntry ? root.entry.name : ""
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: closeBtn
            anchors { right: parent.right; top: parent.top; margins: 10 }
            width: 24; height: 24; radius: 12
            color: closeArea.containsMouse ? Theme.hover : "transparent"
            Image {
                anchors.centerIn: parent
                width: 12; height: 12
                sourceSize: Qt.size(24, 24)
                source: Theme.icon("window-close-symbolic", Theme.textDim)
            }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.shown = false }
        }

        Loader {
            id: content
            anchors { left: parent.left; right: parent.right; top: titleText.bottom; bottom: footer.top; margins: 16 }
            active: root.hasEntry && root.visible
            sourceComponent: {
                if (!root.hasEntry) return null
                if (root.entry.isDir) return iconComp
                switch (root.entry.preview) {
                case "image": return root.entry.mime === "image/gif" ? gifComp : imageComp
                case "text": return textComp
                case "thumb": return thumbComp
                default: return iconComp
                }
            }
        }

        Text {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            font.pixelSize: 12
            elide: Text.ElideMiddle
            text: !root.hasEntry ? ""
                : [root.entry.typeName,
                   root.entry.isDir ? Theme.itemsLabel(root.entry.itemCount) : Theme.sizeLabel(root.entry.size),
                   "Modificado: " + Theme.dateLabel(root.entry.modified)].join("  ·  ")
        }
    }

    Component {
        id: imageComp
        Image {
            source: root.ops.fileUrl(root.entry.path)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            autoTransform: true
            sourceSize: Qt.size(2048, 2048)
            smooth: true
            mipmap: true
        }
    }
    Component {
        id: gifComp
        AnimatedImage {
            source: root.ops.fileUrl(root.entry.path)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }
    Component {
        id: thumbComp
        Image {
            source: "image://thumb/" + root.entry.thumb
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(256, 256)
            smooth: true
        }
    }
    Component {
        id: textComp
        ScrollView {
            clip: true
            TextArea {
                readOnly: true
                text: root.ops.readText(root.entry.path)
                color: Theme.text
                font.family: "monospace"
                font.pixelSize: 12
                wrapMode: TextEdit.NoWrap
                selectByMouse: true
                selectionColor: Theme.accent
                background: Rectangle { radius: 8; color: Qt.rgba(0, 0, 0, 0.25) }
            }
        }
    }
    Component {
        id: iconComp
        Item {
            FolderIcon {
                visible: root.entry.isDir
                anchors.centerIn: parent
                width: 192; height: 192
                glyph: root.entry.glyph || ""
            }
            Image {
                visible: !root.entry.isDir
                anchors.centerIn: parent
                width: 160; height: 160
                sourceSize: Qt.size(256, 256)
                source: root.entry.isDir ? "" : Theme.icon(root.entry.icon)
            }
        }
    }
}
