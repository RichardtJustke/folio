import QtQuick
import Folio

Item {
    id: root

    required property var entry
    required property var view
    property bool selected: false
    property bool renaming: false

    height: Theme.tileHeight

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: interaction.hovered && !root.selected ? 4 : 6 // sobe 2px ao passar o mouse
        Behavior on y { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutQuad } }
        width: parent.width - 8
        spacing: 4
        opacity: interaction.dragging ? 0.4 : root.entry.isHidden ? 0.55 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }

        Rectangle { // destaque atrás do ícone
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.iconSize + 12; height: Theme.iconSize + 8
            radius: 8
            color: interaction.dropHover ? Theme.accentGlow
                 : root.selected ? Theme.selected
                 : interaction.hovered ? Theme.overlay(0.03) : "transparent"
            border.width: interaction.dropHover ? 1.5 : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.dur(120) } }

            FolderIcon {
                visible: root.entry.isDir
                anchors.centerIn: parent
                width: Theme.iconSize; height: Theme.iconSize
                glyph: root.entry.glyph
            }
            Image {
                visible: !root.entry.isDir && !thumb.ready
                anchors.centerIn: parent
                width: Theme.iconSize - 12; height: width
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
                source: root.entry.isDir ? ""
                      : Settings.fileIcons === "system" ? Theme.icon(root.entry.icon) + "&pack=0"
                      : Theme.fileIcon(root.entry.icon, root.entry.name)
            }
            Image { // miniatura freedesktop
                id: thumb
                readonly property bool ready: status === Image.Ready
                visible: ready
                anchors.centerIn: parent
                width: Theme.iconSize - 4; height: width
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                source: root.entry.thumb ? "image://thumb/" + root.entry.thumb : ""
            }
            Rectangle { // moldura da miniatura
                visible: thumb.ready
                anchors.centerIn: parent
                width: thumb.paintedWidth + 2; height: thumb.paintedHeight + 2
                color: "transparent"
                border.width: 1
                border.color: Theme.overlay(0.18)
                radius: 2
            }
            Image { // emblema de link simbólico
                visible: root.entry.isSymlink
                anchors { left: parent.left; bottom: parent.bottom; margins: 6 }
                width: 16; height: 16
                sourceSize: Qt.size(32, 32)
                source: Theme.icon("emblem-symbolic-link")
            }
        }

        Item { // nome (ou editor)
            width: parent.width
            height: root.renaming ? editor.height : nameBg.height

            Rectangle {
                id: nameBg
                visible: !root.renaming
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, name.implicitWidth + 10)
                height: name.height + 2
                radius: 4
                color: root.selected ? Theme.accentSoft : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur(120) } }

                Text {
                    id: name
                    anchors.centerIn: parent
                    width: Math.min(root.width - 18, implicitWidth)
                    text: root.entry.name
                    color: root.selected ? "white" : Theme.text
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideMiddle
                }
            }

            RenameField {
                id: editor
                visible: root.renaming
                width: parent.width
                entry: root.entry
                horizontalAlignment: Text.AlignHCenter
                onCommitted: n => root.view.commitRename(root.entry.path, n)
                onCanceled: root.view.cancelRename()
            }
        }

        Row { // etiquetas + "X itens" / tamanho / local (busca)
            visible: !root.renaming
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5
            TagDots { anchors.verticalCenter: parent.verticalCenter; tags: root.entry.tags }
        Text {
            width: Math.min(root.width - 24, implicitWidth)
            elide: Text.ElideMiddle
            text: root.view.showLocation ? root.entry.location
                : root.entry.isDir ? Theme.itemsLabel(root.entry.itemCount)
                : Theme.sizeLabel(root.entry.size)
            color: Theme.info
            font.pixelSize: 11
        }
        }
    }

    FileInteraction {
        id: interaction
        entry: root.entry
        view: root.view
        active: !root.renaming
    }
}
