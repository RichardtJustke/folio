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
    readonly property bool dragging: mouse.drag.active // o item arrastado fica esmaecido

    anchors.fill: parent

    // ── efeitos no item (o pai: FileTile / FileListRow) ──
    property real slideX: 0
    property real slideY: 0
    property real shakeX: 0
    Translate { id: fxShift; x: root.slideX + root.shakeX; y: root.slideY }

    // vizinhos deslizam para o novo lugar quando algo some ou muda de ordem
    function slideFrom(dx, dy) {
        if (!Theme.motion) return
        slideX = dx
        slideY = dy
        slideAnim.restart()
    }
    ParallelAnimation {
        id: slideAnim
        NumberAnimation { target: root; property: "slideX"; to: 0; duration: Theme.dur(320); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "slideY"; to: 0; duration: Theme.dur(320); easing.type: Easing.OutCubic }
    }

    // item novo (criado, extraído, colado): cresce com leve "mola", em cascata
    function pop(order) {
        if (!Theme.motion || !parent) return
        popAnim.delay = Math.min(order, 8) * 60
        popAnim.restart()
    }
    SequentialAnimation {
        id: popAnim
        property int delay: 0
        ScriptAction { script: { root.parent.scale = 0.6; root.parent.opacity = 0 } }
        PauseAnimation { duration: Theme.dur(popAnim.delay) }
        ParallelAnimation {
            NumberAnimation { target: root.parent; property: "opacity"; to: 1; duration: Theme.dur(160) }
            SequentialAnimation {
                NumberAnimation { target: root.parent; property: "scale"; to: 1.06; duration: Theme.dur(230); easing.type: Easing.OutCubic }
                NumberAnimation { target: root.parent; property: "scale"; to: 1; duration: Theme.dur(150); easing.type: Easing.InOutQuad }
            }
        }
    }

    function shake() {
        if (!Theme.motion) return
        shakeAnim.restart()
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -7; duration: Theme.dur(60) }
        NumberAnimation { target: root; property: "shakeX"; to: 7; duration: Theme.dur(90) }
        NumberAnimation { target: root; property: "shakeX"; to: -4; duration: Theme.dur(80) }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Theme.dur(60) }
    }

    Component.onCompleted: {
        parent.transform = fxShift
        view.registerTile(root)
    }
    Component.onDestruction: if (view) view.unregisterTile(root)

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
            else if (e.button === Qt.LeftButton && Settings.singleClick && !(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)))
                root.view.activate(root.entry)
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
