import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Folio

Window {
    id: win

    width: 1100
    height: 700
    minimumWidth: 320
    minimumHeight: 260
    // aberto pelo D-Bus ("Mostrar na pasta"): a janela só aparece no primeiro pedido
    visible: !Qt.application.arguments.includes("--dbus-service")
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: fm ? fm.title : "Folio"

    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen

    // ── layout responsivo ──
    // auto: barra lateral cheia (≥860), só ícones (≥560) ou oculta
    readonly property string sidebarState: {
        const m = Settings.sidebarMode
        if (m !== "auto") return m
        return width >= 860 ? "full" : width >= 560 ? "compact" : "hidden"
    }
    property bool settingsOpen: false
    // painel de prévia (F3): some sozinho em janelas estreitas
    readonly property bool previewShown: Settings.previewPanel && width >= 760 && !settingsOpen

    function toggleSidebar() {
        Settings.sidebarMode = sidebarState === "hidden" ? "full" : "hidden"
    }

    // 2 cliques no topo: maximizar; 3 cliques: tela cheia
    property int topClicks: 0
    Timer { id: topClickTimer; interval: 400; onTriggered: win.topClicks = 0 }
    function topClick() {
        topClicks++
        topClickTimer.restart()
        if (topClicks === 2) {
            visibility === Window.Maximized ? showNormal() : showMaximized()
        } else if (topClicks >= 3) {
            topClicks = 0
            toggleFullscreen()
        }
    }

    function toggleFullscreen() {
        visibility = visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }

    function openPath(typed) {
        const dir = fileOps.resolveDir(typed)
        if (dir) { nav.go(dir); return }
        const p = typed.trim().replace(/^~/, Settings.home)
        if (p.startsWith("/") && fileOps.parentDir(p) !== "" && fileOps.resolveDir(fileOps.parentDir(p))) {
            toast.show("“" + typed.trim() + "” não encontrado", true)
        } else {
            toast.show("Caminho inválido", true)
        }
    }

    function showProperties(paths) { if (paths.length > 0) propertiesDialog.show(paths) }

    function promptSelectPattern() {
        promptDialog.ask("Selecionar itens por padrão", "ex.: *.png", "Selecionar", v => {
            const n = fm.selectMatching(v)
            toast.show(n === 1 ? "1 item selecionado" : n + " itens selecionados")
            focusView()
        })
    }

    function zoom(delta) { Settings.iconSize = Settings.iconSize + delta }

    // ── abas ──
    ListModel { id: tabs } // { startPath, revealPath, title }
    property int currentTab: 0
    // itemAt() ainda retorna null durante itemAdded; guardamos as abas a partir dos sinais
    property var tabItems: []
    readonly property var tab: tabItems[currentTab] ?? null
    readonly property FileModel fm: tab ? tab.fileModel : null
    readonly property Navigator nav: tab ? tab.navigator : null

    // divisão: duas abas lado a lado (a aba ativa é a do painel em foco)
    property int splitLeft: -1
    property int splitRight: -1
    readonly property bool split: splitLeft >= 0 && splitRight >= 0

    // escolher uma aba sempre sai das Configurações; em divisão, a aba nova ocupa o painel ativo
    function selectTab(i) {
        settingsOpen = false
        if (split && i !== splitLeft && i !== splitRight) {
            if (currentTab === splitRight) splitRight = i
            else splitLeft = i
        }
        currentTab = i
        Qt.callLater(focusView)
    }

    function newTab(path, reveal) {
        tabs.append({ startPath: path, revealPath: reveal ?? "", title: "" })
        selectTab(tabs.count - 1)
    }

    function closeTab(i) {
        if (tabs.count <= 1) { win.close(); return }
        const next = i < currentTab || (i === currentTab && i === tabs.count - 1) ? currentTab - 1 : currentTab
        let l = splitLeft, r = splitRight
        if (i === l || i === r) { l = -1; r = -1 }
        else { if (l > i) l--; if (r > i) r-- }
        tabs.remove(i)
        splitLeft = l
        splitRight = r
        currentTab = next
    }

    function toggleSplit() {
        settingsOpen = false
        if (split) { splitLeft = -1; splitRight = -1; return }
        const cur = currentTab
        if (tabs.count < 2) tabs.append({ startPath: fm ? fm.path : fileOps.startPath(), revealPath: "", title: "" })
        const other = cur === tabs.count - 1 ? cur - 1 : cur + 1
        splitLeft = Math.min(cur, other)
        splitRight = Math.max(cur, other)
        currentTab = cur
    }

    function focusView() { if (tab) tab.view.forceActiveFocus() }

    onCurrentTabChanged: Qt.callLater(focusView)
    Component.onCompleted: {
        newTab(fileOps.startPath(), fileOps.startReveal())
        if (Qt.application.arguments.includes("--settings")) settingsOpen = true
    }

    // "Mostrar na pasta" de outros apps (org.freedesktop.FileManager1)
    Connections {
        target: fileManager1
        function onOpenRequested(folder, reveal) {
            if (!win.visible) {
                // a aba inicial ainda não foi vista: reaproveita
                win.nav.reset(folder)
                if (reveal) win.fm.selectPath(reveal)
                win.show()
            } else {
                win.newTab(folder, reveal)
            }
            win.raise()
            win.requestActivate()
        }
        function onPropertiesRequested(paths) {
            win.show()
            win.raise()
            win.requestActivate()
            win.showProperties(paths)
        }
    }

    // ── serviços compartilhados ──
    FileOps {
        id: fileOps
        onErrorOccurred: msg => { toast.show(msg, true); toast.shake(); if (win.tab && win.fm) win.tab.view.shake(win.fm.selectedPaths()) }
        onFinished: msg => toast.show(msg)
        onConflict: (name, dir, isDir) => conflictDialog.ask(name, dir, isDir)
        onServerConnected: path => { connectDialog.close(); nav.go(path) }
    }

    PlacesModel {
        id: placesModel
        onErrorOccurred: msg => toast.show(msg || "Falha ao ejetar", true)
    }

    // para onde voam os itens que vão para a Lixeira (o ícone dela na barra; canto da janela se a barra estiver oculta)
    function trashTarget() {
        const t = sidebar.targetFor(fileOps.trashDir)
        return t ? t : Qt.point(28, win.height - 28)
    }

    function animateToTrash(paths) {
        if (!Theme.motion || !tab) return
        const items = tab.view.ghostItems(paths)
        if (items.length === 0) return
        const t = trashTarget()
        fx.fly(items, t.x, t.y, () => sidebar.pulse(fileOps.trashDir))
    }

    function animateVanish(paths) {
        if (!Theme.motion || !tab) return
        fx.shrink(tab.view.ghostItems(paths))
    }

    function requestDelete(paths, permanent) {
        if (paths.length === 0) return
        if (!permanent && !fm.isTrash) { animateToTrash(paths); fileOps.trash(paths); return }
        if (!Settings.confirmTrash) { animateVanish(paths); fileOps.deletePermanently(paths); return }
        const what = paths.length === 1 ? "“" + paths[0].split("/").pop() + "”" : paths.length + " itens"
        confirmDialog.ask("Excluir " + what + " permanentemente?",
                          "Esta ação não pode ser desfeita.", "Excluir",
                          () => { animateVanish(paths); fileOps.deletePermanently(paths) })
    }

    function requestEmptyTrash() {
        confirmDialog.ask("Esvaziar a Lixeira?", "Todos os itens da Lixeira serão excluídos permanentemente.",
                          "Esvaziar", () => {
                              if (tab && fm.isTrash) animateVanish(tab.view.visiblePaths())
                              const t = trashTarget()
                              fx.burst(t.x, t.y)
                              sidebar.pulse(fileOps.trashDir)
                              fileOps.emptyTrash()
                          })
    }

    // Visualização Rápida cresce a partir da miniatura do item atual
    function openQuickLook() {
        if (!quickLook.shown && tab && fm && fm.currentIndex >= 0) {
            const g = tab.view.ghostItems([fm.entry(fm.currentIndex).path])
            if (g.length) { quickLook.originX = g[0].x - win.width / 2; quickLook.originY = g[0].y - win.height / 2 }
            else { quickLook.originX = 0; quickLook.originY = 0 }
        }
        quickLook.shown = true
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.maximized || win.visibility === Window.FullScreen ? 0 : Theme.radius
        color: Theme.windowBg
        border.width: win.maximized ? 0 : 1
        border.color: Theme.border

        Sidebar {
            id: sidebar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
            width: win.sidebarState === "full" ? Theme.sidebarWidth
                 : win.sidebarState === "compact" ? Theme.sidebarCompactWidth : 0
            visible: width > 0.5
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
            compact: win.sidebarState === "compact"
            onOpenSettings: win.settingsOpen = !win.settingsOpen
            onTopClicked: win.topClick()
            onConnectServer: connectDialog.show()
            window: win
            places: placesModel
            currentPath: win.fm ? win.fm.path : ""
            onAddFolder: promptDialog.ask("Adicionar pasta à barra lateral", "~/Projetos ou /caminho/da/pasta", "Adicionar", v => {
                const dir = fileOps.resolveDir(v)
                if (dir) { placesModel.addFavorite(dir); toast.show("Pasta adicionada") }
                else toast.show("Pasta não encontrada", true)
            })
            onTagClicked: tag => { // busca a etiqueta em toda a pasta pessoal
                win.settingsOpen = false
                if (!win.fm) return
                if (win.fm.path !== Settings.home) win.nav.go(Settings.home)
                win.fm.searchRecursive = true
                win.fm.searchQuery = "tag:" + tag
            }
            onNavigate: path => {
                win.settingsOpen = false
                if (path !== "folio:network") { win.nav.go(path); return }
                if (fileOps.hasNetworkMounts()) win.nav.go(fileOps.networkDir())
                else connectDialog.show()
            }
            onDropOnPlace: (d, path) => {
                if (!d.hasUrls) return
                fileOps.dropUrls(d.urls, path)
                sidebar.pulse(path)
                d.accept(Qt.CopyAction)
            }
        }

        Loader {
            id: header
            readonly property var search: item ? item.search : null
            anchors { left: sidebar.right; right: parent.right; top: parent.top; topMargin: 4; leftMargin: sidebar.visible ? 0 : -4 }
            height: Theme.headerHeight
            active: win.fm !== null
            sourceComponent: HeaderBar {
                window: win
                fileModel: win.fm
                navigator: win.nav
                ops: fileOps
                sidebarHidden: win.sidebarState === "hidden"
                onToggleSidebar: win.toggleSidebar()
                onTopClicked: win.topClick()
                onOpenPath: typed => win.openPath(typed)
                onNewFolder: win.tab.newFolder()
                onEmptyTrash: win.requestEmptyTrash()
                onFocusView: win.focusView()
            }
        }

        TabStrip {
            id: tabStrip
            anchors { left: sidebar.right; right: parent.right; top: header.bottom }
            height: 34
            tabs: tabs
            currentIndex: win.currentTab
            splitActive: win.split
            splitLeft: win.splitLeft
            splitRight: win.splitRight
            onNewTab: win.newTab(win.fm ? win.fm.path : fileOps.startPath())
            onToggleSplit: win.toggleSplit()
            onSelected: i => win.selectTab(i)
            onClosed: i => win.closeTab(i)
            onDropped: (d, i) => {
                if (!d.hasUrls) return
                fileOps.dropUrls(d.urls, win.tabItems[i].fileModel.path)
                d.accept(Qt.CopyAction)
            }
        }

        PreviewPanel {
            id: previewPanel
            ops: fileOps
            fileModel: win.fm ?? emptyModel
            anchors { right: parent.right; top: tabStrip.bottom; bottom: parent.bottom; margins: 8; topMargin: 4 }
            width: win.previewShown ? 260 : 0
            opacity: win.previewShown ? 1 : 0
            visible: opacity > 0 && win.fm !== null
            Behavior on width { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
        }
        FileModel { id: emptyModel } // o painel precisa de um modelo mesmo sem abas

        Rectangle { // fundo de leitura da área de arquivos
            visible: !win.settingsOpen
            anchors { left: sidebar.right; right: previewPanel.visible ? previewPanel.left : parent.right; top: tabStrip.bottom; bottom: parent.bottom; leftMargin: 4; margins: 4 }
            radius: Theme.radius - 4
            color: Theme.contentBacking
        }

        Item { // painéis: uma aba, ou duas lado a lado (divisão)
            id: paneArea
            opacity: win.settingsOpen ? 0 : 1 // com Configurações aberta, a vista de arquivos some (não vaza por trás do vidro)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
            anchors {
                left: sidebar.right; right: previewPanel.visible ? previewPanel.left : parent.right; top: tabStrip.bottom; bottom: parent.bottom
                leftMargin: 4; rightMargin: previewPanel.visible ? 4 : win.split ? 6 : 0; bottomMargin: win.split ? 6 : 0
            }
            readonly property bool vertical: width < 640 // janela estreita: painéis um sobre o outro
            readonly property int gap: 10
            property real ratio: 0.5
            readonly property real firstSize: Math.round(((vertical ? height : width) - gap) * ratio)

            Repeater {
                id: tabRepeater
                model: tabs
                onItemAdded: (i, item) => { const t = win.tabItems.slice(); t.splice(i, 0, item); win.tabItems = t }
                onItemRemoved: (i, item) => { const t = win.tabItems.slice(); t.splice(i, 1); win.tabItems = t }
                BrowserTab {
                    id: pane
                    readonly property bool isRight: win.split && index === win.splitRight
                    readonly property bool shown: win.split ? (index === win.splitLeft || isRight) : index === win.currentTab
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    enabled: shown
                    z: index === win.currentTab ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
                    transform: Translate {
                        x: pane.isRight ? (1 - pane.opacity) * 24 : 0 // o segundo painel desliza da borda
                    }
                    x: isRight && !paneArea.vertical ? paneArea.firstSize + paneArea.gap : 0
                    y: isRight && paneArea.vertical ? paneArea.firstSize + paneArea.gap : 0
                    width: win.split && !paneArea.vertical
                           ? (isRight ? paneArea.width - paneArea.firstSize - paneArea.gap : paneArea.firstSize)
                           : paneArea.width
                    height: win.split && paneArea.vertical
                            ? (isRight ? paneArea.height - paneArea.firstSize - paneArea.gap : paneArea.firstSize)
                            : paneArea.height
                    ops: fileOps
                    places: placesModel
                    onOpenInNewTab: path => win.newTab(path)
                    onTitleUpdated: (i, title) => { if (i < tabs.count) tabs.setProperty(i, "title", title) }
                    onRequestDelete: (paths, permanent) => win.requestDelete(paths, permanent)
                    onRequestEmptyTrash: win.requestEmptyTrash()
                    onQuickLook: win.openQuickLook()
                    onShowProperties: paths => win.showProperties(paths)
                    onOpenWith: path => openWithDialog.show(path)
                    onRenameMany: paths => batchRename.show(paths)
                    onPromptSelectPattern: win.promptSelectPattern()

                    // clicar num painel o torna o ativo (é o que o cabeçalho e os atalhos controlam)
                    Connections {
                        target: pane.view
                        function onActiveFocusChanged() {
                            if (pane.view.activeFocus && !win.settingsOpen) win.currentTab = pane.index
                        }
                    }
                    Rectangle { // contorno do painel (só em divisão)
                        anchors.fill: parent
                        z: 5
                        visible: win.split
                        color: "transparent"
                        radius: Theme.radius - 4
                        border.width: 1
                        border.color: pane.index === win.currentTab ? Theme.tint(Theme.accent, 0.55) : Theme.border
                    }
                }
            }

            Item { // divisor arrastável (duplo clique: 50/50)
                visible: win.split
                x: paneArea.vertical ? 0 : paneArea.firstSize
                y: paneArea.vertical ? paneArea.firstSize : 0
                width: paneArea.vertical ? paneArea.width : paneArea.gap
                height: paneArea.vertical ? paneArea.gap : paneArea.height
                Rectangle {
                    anchors.centerIn: parent
                    width: paneArea.vertical ? 44 : 3
                    height: paneArea.vertical ? 3 : 44
                    radius: 2
                    color: dividerArea.containsMouse || dividerArea.pressed ? Theme.accent : Theme.borderStrong
                }
                MouseArea {
                    id: dividerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: paneArea.vertical ? Qt.SplitVCursor : Qt.SplitHCursor
                    onPositionChanged: e => {
                        if (!pressed) return
                        const p = mapToItem(paneArea, e.x, e.y)
                        const total = (paneArea.vertical ? paneArea.height : paneArea.width) - paneArea.gap
                        const v = (paneArea.vertical ? p.y : p.x) - paneArea.gap / 2
                        paneArea.ratio = Math.max(0.25, Math.min(0.75, v / total))
                    }
                    onDoubleClicked: paneArea.ratio = 0.5
                }
            }
        }
        SettingsPage {
            id: settingsPage
            ops: fileOps
            opacity: win.settingsOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - settingsPage.opacity) * 10 }
            anchors { left: sidebar.right; right: parent.right; top: tabStrip.bottom; bottom: parent.bottom; margins: 6; leftMargin: 4; topMargin: 2 }
            onClosed: win.settingsOpen = false
        }
    }

    FxLayer { id: fx; z: 60 }

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
    PromptDialog { id: promptDialog }
    BatchRenameDialog { id: batchRename; ops: fileOps; onClosed: win.focusView() }
    ConnectDialog { id: connectDialog; ops: fileOps }
    PropertiesDialog { id: propertiesDialog; ops: fileOps }
    OpenWithDialog { id: openWithDialog; ops: fileOps }

    // ── atalhos (desativados durante edição de texto/diálogos) ──
    readonly property bool typing: (fm && fm.renamingPath !== "") || (header.search !== null && header.search.active)
                                   || confirmDialog.opened || conflictDialog.opened || promptDialog.opened
                                   || propertiesDialog.opened || openWithDialog.opened || connectDialog.opened || settingsOpen
    readonly property bool ready: fm !== null && !typing

    Shortcut { sequences: [StandardKey.Copy]; enabled: win.ready; onActivated: fileOps.copy(fm.selectedPaths()) }
    Shortcut { sequences: [StandardKey.Cut]; enabled: win.ready && !fm.isTrash; onActivated: fileOps.cut(fm.selectedPaths()) }
    Shortcut { sequences: [StandardKey.Paste]; enabled: win.ready && !fm.isTrash; onActivated: fileOps.paste(fm.path) }
    Shortcut { sequences: [StandardKey.Undo]; enabled: win.ready; onActivated: fileOps.undo() }
    Shortcut { sequence: "Delete"; enabled: win.ready; onActivated: win.requestDelete(fm.selectedPaths(), false) }
    Shortcut { sequence: "Shift+Delete"; enabled: win.ready; onActivated: win.requestDelete(fm.selectedPaths(), true) }
    Shortcut {
        sequence: "F2" // um item: renomeia no lugar; vários: renomear em lote
        enabled: win.ready && fm.selectedCount >= 1 && !fm.isTrash
        onActivated: fm.selectedCount === 1 ? fm.renamingPath = fm.selectedPaths()[0] : batchRename.show(fm.selectedPaths())
    }
    Shortcut { sequence: "Space"; enabled: win.ready; onActivated: quickLook.shown ? quickLook.shown = false : win.openQuickLook() }
    Shortcut { sequence: "Escape"; enabled: quickLook.shown; onActivated: quickLook.shown = false }
    Shortcut { sequences: ["Alt+Left", "Backspace"]; enabled: win.ready; onActivated: nav.back() }
    Shortcut { sequence: "Alt+Right"; enabled: win.ready; onActivated: nav.forward() }
    Shortcut { sequence: "Alt+Up"; enabled: win.ready; onActivated: nav.up() }
    Shortcut { sequence: "Alt+Home"; enabled: win.ready; onActivated: nav.go("~") }
    Shortcut { sequence: "Ctrl+H"; enabled: win.ready; onActivated: fm.showHidden = !fm.showHidden }
    Shortcut { sequences: [StandardKey.SelectAll]; enabled: win.ready; onActivated: fm.selectAll() }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: win.ready && !fm.isTrash; onActivated: tab.newFolder() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; enabled: win.ready; onActivated: fm.reload() }
    Shortcut { sequences: [StandardKey.Find]; enabled: fm !== null; onActivated: if (header.search) header.search.focusField() }
    Shortcut { sequences: ["Ctrl+L"]; enabled: fm !== null; onActivated: if (header.item) header.item.pathBar.edit() }
    Shortcut { sequences: ["Ctrl+B", "F9"]; onActivated: win.toggleSidebar() }
    Shortcut { sequences: ["F11"]; onActivated: win.toggleFullscreen() }
    Shortcut { sequence: "Ctrl+,"; onActivated: win.settingsOpen = !win.settingsOpen }
    Shortcut { sequence: "Escape"; enabled: win.settingsOpen; onActivated: win.settingsOpen = false }
    Shortcut { sequences: ["Alt+Return", "Ctrl+I"]; enabled: win.ready; onActivated: win.showProperties(fm.selectedPaths().length ? fm.selectedPaths() : [fm.path]) }
    Shortcut { sequence: "Ctrl+Shift+I"; enabled: win.ready; onActivated: fm.invertSelection() }
    Shortcut { sequence: "Ctrl+S"; enabled: win.ready; onActivated: win.promptSelectPattern() }
    Shortcut { sequence: "Ctrl+D"; enabled: win.ready && !fm.isTrash; onActivated: placesModel.addFavorite(fm.path) }
    Shortcut { sequence: "Ctrl+N"; onActivated: fileOps.openNewWindow(fm ? fm.path : fileOps.startPath()) }
    Shortcut { sequence: "Ctrl+Shift+C"; enabled: win.ready; onActivated: fileOps.copyText(fm.selectedPaths().length ? fm.selectedPaths().join("\n") : fm.path) }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: win.zoom(8) }
    Shortcut { sequence: "Ctrl+-"; onActivated: win.zoom(-8) }
    Shortcut { sequence: "Ctrl+0"; onActivated: Settings.iconSize = 76 }
    Shortcut { sequence: "Ctrl+Alt+N"; enabled: win.ready && !fm.isTrash; onActivated: tab.newFile() }
    Shortcut { sequence: "Ctrl+1"; enabled: win.ready; onActivated: fm.viewMode = "grid" }
    Shortcut { sequence: "Ctrl+2"; enabled: win.ready; onActivated: fm.viewMode = "list" }
    Shortcut { // terminal na pasta atual (na busca: na pasta do item selecionado)
        sequence: "F4"
        enabled: fm !== null && !fm.isTrash
        onActivated: {
            const sel = fm.selectedPaths()
            fileOps.openTerminal(fm.isSearch && sel.length > 0 ? fileOps.parentDir(sel[0]) : fm.path)
        }
    }
    Shortcut { sequence: "F3"; onActivated: Settings.previewPanel = !Settings.previewPanel }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab(fm ? fm.path : fileOps.startPath()) }
    Shortcut { sequence: "Ctrl+W"; onActivated: tabStrip.requestClose(win.currentTab) }
    Shortcut { sequences: ["Ctrl+\\", "F6"]; onActivated: win.toggleSplit() }
    Shortcut { sequence: "Ctrl+Tab"; enabled: tabs.count > 1; onActivated: win.selectTab((win.currentTab + 1) % tabs.count) }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: tabs.count > 1
        onActivated: win.selectTab((win.currentTab - 1 + tabs.count) % tabs.count)
    }
    Shortcut { sequences: [StandardKey.Quit]; onActivated: win.close() }
}
