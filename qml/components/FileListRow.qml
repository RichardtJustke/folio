import QtQuick
import Folio

Item {
    id: root

    required property var entry
    required property var view
    property bool selected: false
    property bool renaming: false

    height: Theme.listRowHeight

    readonly property color fg: selected ? "white" : Theme.text
    readonly property color fgDim: selected ? Theme.overlay(0.85) : Theme.textDim

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: interaction.dropHover ? Theme.accentGlow
             : root.selected ? Theme.accentSoft
             : root.entry.index % 2 ? Theme.overlay(0.025) : "transparent"
        border.width: interaction.dropHover ? 1.5 : 0
        border.color: Theme.accent
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        opacity: root.entry.isHidden ? 0.55 : 1

        Item {
            width: root.view.nameWidth - 8
            height: parent.height

            Image {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                sourceSize: Qt.size(36, 36)
                asynchronous: true
                source: root.entry.isDir ? Theme.folderSvg : Theme.icon(root.entry.icon)
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
            text: root.entry.isDir ? Theme.itemsLabel(root.entry.itemCount) : Theme.sizeLabel(root.entry.size)
        }
        Cell {
            width: root.view.typeWidth
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
