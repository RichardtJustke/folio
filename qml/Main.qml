import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Folio

Window {
    id: win

    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 420
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: fm ? fm.title : "Folio"

    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen

    // ── abas ──
    ListModel { id: tabs } // { startPath, title }
    property int currentTab: 0
    // itemAt() ainda retorna null durante itemAdded; guardamos as abas a partir dos sinais
    property var tabItems: []
    readonly property var tab: tabItems[currentTab] ?? null
    readonly property FileModel fm: tab ? tab.fileModel : null
    readonly property Navigator nav: tab ? tab.navigator : null

    function newTab(path) {
        tabs.append({ startPath: path, title: "" })
        currentTab = tabs.count - 1
    }

    function closeTab(i) {
        if (tabs.count <= 1) { win.close(); return }
        const next = i < currentTab || (i === currentTab && i === tabs.count - 1) ? currentTab - 1 : currentTab
        tabs.remove(i)
        currentTab = next
    }

    function focusView() { if (tab) tab.view.forceActiveFocus() }

    onCurrentTabChanged: Qt.callLater(focusView)
    Component.onCompleted: newTab(fileOps.startPath())

    // ── serviços compartilhados ──
    FileOps {
        id: fileOps
        onErrorOccurred: msg => toast.show(msg, true)
        onFinished: msg => toast.show(msg)
        onConflict: (name, dir, isDir) => conflictDialog.ask(name, dir, isDir)
    }

    PlacesModel {
        id: placesModel
        onErrorOccurred: msg => toast.show(msg || "Falha ao ejetar", true)
    }

    function requestDelete(paths, permanent) {
        if (paths.length === 0) return
        if (!permanent && !fm.isTrash) { fileOps.trash(paths); return }
        const what = paths.length === 1 ? "“" + paths[0].split("/").pop() + "”" : paths.length + " itens"
        confirmDialog.ask("Excluir " + what + " permanentemente?",
                          "Esta ação não pode ser desfeita.", "Excluir",
                          () => fileOps.deletePermanently(paths))
    }

    function requestEmptyTrash() {
        confirmDialog.ask("Esvaziar a Lixeira?", "Todos os itens da Lixeira serão excluídos permanentemente.",
                          "Esvaziar", () => fileOps.emptyTrash())
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.maximized ? 0 : Theme.radius
        color: Theme.windowBg
        border.width: win.maximized ? 0 : 1
        border.color: Theme.border

        Sidebar {
            id: sidebar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
            width: Theme.sidebarWidth
            window: win
            places: placesModel
            currentPath: win.fm ? win.fm.path : ""
            onNavigate: path => win.nav.go(path)
            onDropOnPlace: (d, path) => {
                if (!d.hasUrls) return
                fileOps.dropUrls(d.urls, path)
                d.accept(Qt.CopyAction)
            }
        }

        Loader {
            id: header
            readonly property var search: item ? item.search : null
            anchors { left: sidebar.right; right: parent.right; top: parent.top; topMargin: 4 }
            height: Theme.headerHeight
            active: win.fm !== null
            sourceComponent: HeaderBar {
                window: win
                fileModel: win.fm
                navigator: win.nav
                ops: fileOps
                onNewFolder: win.tab.newFolder()
                onEmptyTrash: win.requestEmptyTrash()
                onFocusView: win.focusView()
            }
        }

        TabStrip {
            id: tabStrip
            anchors { left: sidebar.right; right: parent.right; top: header.bottom }
            visible: tabs.count > 1
            height: visible ? 34 : 0
            tabs: tabs
            currentIndex: win.currentTab
            onSelected: i => win.currentTab = i
            onClosed: i => win.closeTab(i)
            onDropped: (d, i) => {
                if (!d.hasUrls) return
                fileOps.dropUrls(d.urls, win.tabItems[i].fileModel.path)
                d.accept(Qt.CopyAction)
            }
        }

        StackLayout {
            anchors { left: sidebar.right; right: parent.right; top: tabStrip.bottom; bottom: parent.bottom; leftMargin: 4 }
            currentIndex: win.currentTab

            Repeater {
                id: tabRepeater
                model: tabs
                onItemAdded: (i, item) => { const t = win.tabItems.slice(); t.splice(i, 0, item); win.tabItems = t }
                onItemRemoved: (i, item) => { const t = win.tabItems.slice(); t.splice(i, 1); win.tabItems = t }
                BrowserTab {
                    ops: fileOps
                    places: placesModel
                    onOpenInNewTab: path => win.newTab(path)
                    onTitleUpdated: (i, title) => { if (i < tabs.count) tabs.setProperty(i, "title", title) }
                    onRequestDelete: (paths, permanent) => win.requestDelete(paths, permanent)
                    onRequestEmptyTrash: win.requestEmptyTrash()
                    onQuickLook: quickLook.shown = true
                }
            }
        }
    }

    QuickLook {
        id: quickLook
        ops: fileOps
        entry: { if (!win.fm) return ({}); win.fm.revision; return win.fm.entry(win.fm.currentIndex) }
        onShownChanged: if (!shown) win.focusView()
    }

    ResizeHandles { window: win }
    Toast { id: toast }
    ConfirmDialog { id: confirmDialog }
    ConflictDialog { id: conflictDialog; ops: fileOps }

    // ── atalhos (desativados durante edição de texto/diálogos) ──
    readonly property bool typing: (fm && fm.renamingPath !== "") || (header.search !== null && header.search.active)
                                   || confirmDialog.opened || conflictDialog.opened
    readonly property bool ready: fm !== null && !typing

    Shortcut { sequences: [StandardKey.Copy]; enabled: win.ready; onActivated: fileOps.copy(fm.selectedPaths()) }
    Shortcut { sequences: [StandardKey.Cut]; enabled: win.ready && !fm.isTrash; onActivated: fileOps.cut(fm.selectedPaths()) }
    Shortcut { sequences: [StandardKey.Paste]; enabled: win.ready && !fm.isTrash; onActivated: fileOps.paste(fm.path) }
    Shortcut { sequences: [StandardKey.Undo]; enabled: win.ready; onActivated: fileOps.undo() }
    Shortcut { sequence: "Delete"; enabled: win.ready; onActivated: win.requestDelete(fm.selectedPaths(), false) }
    Shortcut { sequence: "Shift+Delete"; enabled: win.ready; onActivated: win.requestDelete(fm.selectedPaths(), true) }
    Shortcut {
        sequence: "F2"
        enabled: win.ready && fm.selectedCount === 1 && !fm.isTrash
        onActivated: fm.renamingPath = fm.selectedPaths()[0]
    }
    Shortcut { sequence: "Space"; enabled: win.ready; onActivated: quickLook.shown = !quickLook.shown }
    Shortcut { sequence: "Escape"; enabled: quickLook.shown; onActivated: quickLook.shown = false }
    Shortcut { sequences: ["Alt+Left", "Backspace"]; enabled: win.ready; onActivated: nav.back() }
    Shortcut { sequence: "Alt+Right"; enabled: win.ready; onActivated: nav.forward() }
    Shortcut { sequence: "Alt+Up"; enabled: win.ready; onActivated: nav.up() }
    Shortcut { sequence: "Alt+Home"; enabled: win.ready; onActivated: nav.go("~") }
    Shortcut { sequence: "Ctrl+H"; enabled: win.ready; onActivated: fm.showHidden = !fm.showHidden }
    Shortcut { sequences: [StandardKey.SelectAll]; enabled: win.ready; onActivated: fm.selectAll() }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: win.ready && !fm.isTrash; onActivated: tab.newFolder() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; enabled: win.ready; onActivated: fm.reload() }
    Shortcut { sequences: [StandardKey.Find, "Ctrl+L"]; enabled: fm !== null; onActivated: if (header.search) header.search.focusField() }
    Shortcut { sequence: "Ctrl+1"; enabled: win.ready; onActivated: fm.viewMode = "grid" }
    Shortcut { sequence: "Ctrl+2"; enabled: win.ready; onActivated: fm.viewMode = "list" }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab(fm ? fm.path : fileOps.startPath()) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.currentTab) }
    Shortcut { sequence: "Ctrl+Tab"; enabled: tabs.count > 1; onActivated: win.currentTab = (win.currentTab + 1) % tabs.count }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: tabs.count > 1
        onActivated: win.currentTab = (win.currentTab - 1 + tabs.count) % tabs.count
    }
    Shortcut { sequences: [StandardKey.Quit]; onActivated: win.close() }
}
