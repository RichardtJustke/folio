import QtQuick
import Folio

Item {
    id: root

    required property var entry
    required property var view
    property bool selected: false
    property bool renaming: false

    height: Theme.listRowHeight

    readonly property color fg: Theme.text
    readonly property color fgDim: Theme.textDim

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: interaction.dropHover ? Theme.accentGlow
             : root.selected ? Theme.selected
             : interaction.hovered ? Theme.overlay(0.035) : "transparent"
        border.width: interaction.dropHover ? 1.5 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        opacity: interaction.dragging ? 0.4 : root.entry.isHidden ? 0.55 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }

        Item {
            width: root.view.nameWidth - 8
            height: parent.height

            Item {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                FolderIcon { visible: root.entry.isDir; anchors.fill: parent; glyph: root.entry.glyph }
                Image {
                    visible: !root.entry.isDir
                    anchors.fill: parent
                    sourceSize: Qt.size(36, 36)
                    asynchronous: true
                    source: root.entry.isDir ? ""
                          : Settings.fileIcons === "system" ? Theme.icon(root.entry.icon) + "&pack=0"
                          : Theme.fileIcon(root.entry.icon, root.entry.name)
                }
            }
            Text {
                visible: !root.renaming
                anchors { left: icon.right; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: root.entry.name
                color: root.fg
                font.pixelSize: Theme.fontSize
                elide: Text.ElideMiddle
            }
            RenameField {
                visible: root.renaming
                anchors { left: icon.right; leftMargin: 6; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                entry: root.entry
                onCommitted: n => root.view.commitRename(root.entry.path, n)
                onCanceled: root.view.cancelRename()
            }
        }

        component Cell: Text {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 10
            color: root.fgDim
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Cell { width: root.view.dateWidth; text: Theme.dateLabel(root.entry.modified) }
        Cell {
            width: root.view.sizeWidth
            horizontalAlignment: Text.AlignRight
            text: root.entry.isDir ? Theme.itemsLabel(root.entry.itemCount) : Theme.sizeLabel(root.entry.size)
        }
        Cell {
            width: root.view.typeWidth
            leftPadding: 14
            text: root.view.showLocation ? root.entry.location : root.entry.typeName
            elide: root.view.showLocation ? Text.ElideMiddle : Text.ElideRight
        }
    }

    FileInteraction {
        id: interaction
        entry: root.entry
        view: root.view
        active: !root.renaming
    }
}
