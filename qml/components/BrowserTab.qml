import QtQuick
import Folio

// Uma aba: histórico + modelo + vista.
Item {
    id: root

    required property int index
    required property string startPath
    required property string revealPath // item a selecionar ao abrir
    required property FileOps ops
    required property PlacesModel places

    property alias navigator: nav
    property alias fileModel: fm
    property alias view: grid

    signal openInNewTab(string path)
    signal titleUpdated(int index, string title)
    signal requestDelete(var paths, bool permanent)
    signal requestEmptyTrash
    signal quickLook
    signal showProperties(var paths)
    signal openWith(string path)
    signal promptSelectPattern

    function activate(entry) {
        if (entry.isDir) nav.go(entry.path)
        else ops.open(entry.path)
    }

    function newFolder() {
        const p = ops.createFolder(fm.path)
        if (!p) return
        fm.selectPath(p)
        fm.renamingPath = p
    }

    function newFile() {
        const p = ops.createFile(fm.path)
        if (!p) return
        fm.selectPath(p)
        fm.renamingPath = p
    }

    function reveal(path) {
        fm.searchQuery = ""
        const dir = ops.parentDir(path)
        if (dir !== fm.path) nav.go(dir)
        fm.selectPath(path)
    }

    Navigator { id: nav }

    FileModel {
        id: fm
        columns: grid.columns
        onPathChanged: root.titleUpdated(root.index, title)
    }

    Connections {
        target: nav
        function onCurrentPathChanged() {
            fm.path = nav.currentPath
            fm.selectPath(nav.lastLeft) // re-seleciona a pasta de onde viemos
        }
    }

    Component.onCompleted: {
        nav.reset(startPath)
        if (revealPath) fm.selectPath(revealPath)
    }
    onIndexChanged: titleUpdated(index, fm.title)

    FileGrid {
        id: grid
        anchors.fill: parent
        fileModel: fm
        ops: root.ops
        places: root.places
        focus: true
        onActivate: entry => root.activate(entry)
        onNewFolder: root.newFolder()
        onNewFile: root.newFile()
        onShowProperties: paths => root.showProperties(paths)
        onOpenWith: path => root.openWith(path)
        onPromptSelectPattern: root.promptSelectPattern()
        onOpenTerminalHere: dir => root.ops.openTerminal(dir)
        onOpenInNewTab: path => root.openInNewTab(path)
        onRevealInFolder: path => root.reveal(path)
        onRequestDelete: (paths, permanent) => root.requestDelete(paths, permanent)
        onRequestEmptyTrash: root.requestEmptyTrash()
        onQuickLook: root.quickLook()
    }
}
