import QtQuick
import Folio

// Mouse, arrastar (DnD nativo, funciona entre apps) e soltar — usado por tiles e linhas.
Item {
    id: root

    required property var entry
    required property var view // FileGrid
    property bool active: true

    readonly property bool hovered: mouse.containsMouse
    readonly property bool dropHover: drop.containsDrag

    anchors.fill: parent

    MouseArea {
        id: mouse

        property bool collapseOnRelease: false

        anchors.fill: parent
        enabled: root.active
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        drag.target: proxy
        drag.threshold: 8

        onPressed: e => {
            root.view.forceActiveFocus()
            collapseOnRelease = false
            const fm = root.view.fileModel
            const selected = fm.isSelected(root.entry.index)
            if (e.button === Qt.MiddleButton)
                return
            if (e.button === Qt.RightButton) {
                if (!selected) fm.select(root.entry.index, 0)
                root.view.openItemMenu()
                return
            }
            // item já selecionado: mantém a seleção para permitir arrastar vários
            if (selected && !(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                collapseOnRelease = true
                fm.currentIndex = root.entry.index
                return
            }
            fm.select(root.entry.index, e.modifiers)
        }
        onReleased: {
            if (collapseOnRelease) root.view.fileModel.select(root.entry.index, 0)
            collapseOnRelease = false
        }
        onClicked: e => {
            if (e.button === Qt.MiddleButton && root.entry.isDir) root.view.openInNewTab(root.entry.path)
        }
        onDoubleClicked: e => { if (e.button === Qt.LeftButton) root.view.activate(root.entry) }
    }

    Item {
        id: proxy
        width: 1; height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.onDragFinished: { proxy.x = 0; proxy.y = 0 }
    }

    Connections {
        target: mouse.drag
        function onActiveChanged() {
            if (!mouse.drag.active) return
            mouse.collapseOnRelease = false
            const paths = root.view.fileModel.selectedPaths()
            proxy.Drag.mimeData = { "text/uri-list": root.view.ops.uriList(paths) }
            proxy.Drag.imageSource = root.entry.isDir ? Theme.folderSvg : Theme.icon(root.entry.icon)
            proxy.Drag.active = true
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.entry.isDir
        onDropped: d => root.view.handleDrop(d, root.entry.path)
    }
}
