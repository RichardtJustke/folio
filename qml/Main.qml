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

    // ── estado da janela ──
    Component.onCompleted: {
        // restaura geometria salva
        const geom = Settings.windowGeometry
        if (geom && geom.x !== undefined) {
            x = geom.x; y = geom.y; width = geom.w; height = geom.h
            if (geom.max) showMaximized()
        }
        // sem caminho na linha de comando, reabre as abas da última sessão
        const explicitPath = Qt.application.arguments.slice(1).some(a => !a.startsWith("--"))
        const savedTabs = Settings.savedTabs
        let active = 0
        if (!explicitPath && savedTabs) {
            for (const t of savedTabs) {
                if (!t.path) continue
                if (t.active) active = tabs.count
                tabs.append({ startPath: t.path, revealPath: "", title: t.title || "" })
            }
        }
        if (tabs.count > 0) selectTab(active)
        else newTab(fileOps.startPath(), fileOps.startReveal())
        if (Qt.application.arguments.includes("--settings")) settingsOpen = true
    }
    Component.onDestruction: {
        // salva geometria
        Settings.windowGeometry = { x: x, y: y, w: width, h: height, max: maximized }
        // salva abas
        const tabState = []
        for (let i = 0; i < tabs.count; i++) {
            const t = tabs.get(i)
            tabState.push({ path: t.startPath, reveal: t.revealPath || "", title: t.title || "", active: i === currentTab })
        }
        Settings.savedTabs = tabState
    }

    // ── layout responsivo ──
    // auto: barra lateral cheia (≥860), só ícones (≥560) ou oculta
    // autohide: oculta, aparece por cima ao encostar o cursor na borda esquerda
    readonly property string sidebarState: {
        const m = Settings.sidebarMode
        if (m === "autohide") return "overlay"
        if (m !== "auto") return m
        return width >= 860 ? "full" : width >= 560 ? "compact" : "hidden"
    }
    property bool sidebarRevealed: false
    readonly property bool sidebarOverlay: sidebarState === "overlay"
    onSidebarOverlayChanged: sidebarRevealed = false
    property bool settingsOpen: false
    // painel de prévia (F3): some sozinho em janelas estreitas
    readonly property bool previewShown: Settings.previewPanel && width >= 760 && !settingsOpen

    function toggleSidebar() {
        if (sidebarOverlay) { sidebarRevealed = !sidebarRevealed; return }
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
        onFinished: msg => {
            const canUndo = fileOps.canUndo
            const label = fileOps.undoLabel
            toast.show(msg, false, canUndo ? (label || "Desfazer") : "", canUndo ? () => fileOps.undo() : null)
        }
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

        Item { // espaço que a barra lateral ocupa no layout (zero quando ela flutua ou está oculta)
            id: dock
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
            width: win.sidebarState === "full" ? Theme.sidebarWidth
                 : win.sidebarState === "compact" ? Theme.sidebarCompactWidth : 0
            Behavior on width { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
        }

        // ── barra lateral automática: a borda esquerda a revela, sair dela a esconde ──
        HoverHandler { id: frameHover }
        Timer {
            id: revealTimer
            interval: 120
            onTriggered: win.sidebarRevealed = true
        }
        Timer {
            id: concealTimer
            interval: 380
            onTriggered: win.sidebarRevealed = false
        }
        // cursor bem à direita da barra (ou fora da janela): esconde. Durante um arraste não há hover, então ela fica
        readonly property bool pointerAway: !frameHover.hovered
            || frameHover.point.position.x > sidebar.x + sidebar.width + 24
        onPointerAwayChanged: {
            if (win.sidebarRevealed && pointerAway) concealTimer.restart()
            else concealTimer.stop()
        }
        Item {
            id: edgeZone
            visible: win.sidebarOverlay && !win.sidebarRevealed
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 6
            z: 40
            HoverHandler {
                onHoveredChanged: hovered ? revealTimer.restart() : revealTimer.stop()
            }
            DropArea { // arrastar um arquivo até a borda também abre (para soltar numa pasta)
                anchors.fill: parent
                onEntered: win.sidebarRevealed = true
            }
            Rectangle { // dica na borda
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 3; height: parent.height * 0.3; radius: 2
                color: Theme.accent
                opacity: revealTimer.running ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
            }
        }

        Rectangle { // sombra e fundo sólido da barra flutuante (a barra em si é translúcida)
            visible: win.sidebarOverlay && sidebar.x > -sidebar.width
            x: sidebar.x; y: sidebar.y
            width: sidebar.width; height: sidebar.height
            z: 29
            radius: sidebar.radius
            color: Theme.tint(Theme.menuBg, 0.96)
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                z: -1
                radius: parent.radius + 6
                color: Qt.rgba(0, 0, 0, Theme.light ? 0.10 : 0.30)
            }
        }

        Sidebar {
            id: sidebar
            anchors { top: parent.top; bottom: parent.bottom; margins: 8 }
            x: !win.sidebarOverlay ? 8 : win.sidebarRevealed ? 8 : -width - 16
            z: win.sidebarOverlay ? 30 : 0
            Behavior on x { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
            width: win.sidebarOverlay ? Theme.sidebarWidth : dock.width
            visible: width > 0.5 && x > -width
            clip: true
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
                if (win.sidebarOverlay) win.sidebarRevealed = false
                if (path !== "folio:network") { win.nav.go(path); return }
                if (fileOps.hasNetworkMounts()) win.nav.go(fileOps.networkDir())
                else connectDialog.show()
            }
            onDropOnPlace: (d, path) => {
                if (!d.hasUrls) return
                fileOps.dropUrls(d.urls, path)
                sidebar.pulse(path)
                d.accept(Qt.CopyAction)
                if (win.sidebarOverlay) concealTimer.restart()
            }
        }

        Loader {
            id: header
            readonly property var search: item ? item.search : null
            anchors { left: dock.right; right: parent.right; top: parent.top; topMargin: 4; leftMargin: dock.width > 0 ? 0 : -4 }
            height: Theme.headerHeight
            active: win.fm !== null
            sourceComponent: HeaderBar {
                window: win
                fileModel: win.fm
                navigator: win.nav
                ops: fileOps
                sidebarHidden: win.sidebarState === "hidden" || win.sidebarOverlay
                onToggleSidebar: win.toggleSidebar()
                onTopClicked: win.topClick()
                onOpenPath: typed => win.openPath(typed)
                onNewFolder: win.tab.newFolder()
                onEmptyTrash: win.requestEmptyTrash()
                onCustomizeToolbar: { settingsPage.openPage("window"); win.settingsOpen = true }
                onFocusView: win.focusView()
            }
        }

        TabStrip {
            id: tabStrip
            anchors { left: dock.right; right: parent.right; top: header.bottom }
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
            onOpenRequested: entry => { if (win.tab) win.tab.activate(entry) }
            onQuickLookRequested: win.openQuickLook()
            onPropertiesRequested: paths => win.showProperties(paths)
        }
        FileModel { id: emptyModel } // o painel precisa de um modelo mesmo sem abas

        Rectangle { // fundo de leitura da área de arquivos
            visible: !win.settingsOpen
            anchors { left: dock.right; right: previewPanel.visible ? previewPanel.left : parent.right; top: tabStrip.bottom; bottom: parent.bottom; leftMargin: 4; margins: 4 }
            radius: Theme.radius - 4
            color: Theme.contentBacking
        }

        // dois dedos para o lado no touchpad: direita = voltar, esquerda = avançar
        SwipeGesture {
            id: swipe
            enabled: Settings.swipeNavigation && win.ready && !win.settingsOpen && !quickLook.shown
                     && !!win.tab && win.tab.fileModel.viewMode !== "column" // colunas rolam para o lado
            invert: Settings.swipeInvert
            onProgress: d => swipeHint.distance = d
            onFinished: d => {
                swipeHint.distance = 0
                if (d >= threshold && win.nav.canGoBack) win.nav.back()
                else if (d <= -threshold && win.nav.canGoForward) win.nav.forward()
            }
        }

        Rectangle { // bolinha com a seta que entra pela borda enquanto os dedos deslizam
            id: swipeHint
            property real distance: 0
            readonly property bool back: distance > 0
            readonly property bool possible: back ? !!win.nav && win.nav.canGoBack : !!win.nav && win.nav.canGoForward
            readonly property real amount: Math.min(1, Math.abs(distance) / swipe.threshold)
            z: 20
            width: 40; height: 40; radius: 20
            anchors.verticalCenter: paneArea.verticalCenter
            x: back ? paneArea.x - width + amount * (width + 18) : paneArea.x + paneArea.width - amount * (width + 18)
            visible: distance !== 0 && possible
            opacity: 0.35 + 0.65 * amount
            color: amount >= 1 ? Theme.accent : Theme.menuBg
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
            Image {
                anchors.centerIn: parent
                width: 18; height: 18
                sourceSize: Qt.size(18, 18)
                source: Theme.icon(swipeHint.back ? "go-previous-symbolic" : "go-next-symbolic",
                                   swipeHint.amount >= 1 ? Theme.accentText : Theme.text)
            }
        }

        Item { // painéis: uma aba, ou duas lado a lado (divisão)
            id: paneArea
            opacity: win.settingsOpen ? 0 : 1 // com Configurações aberta, a vista de arquivos some (não vaza por trás do vidro)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
            anchors {
                left: dock.right; right: previewPanel.visible ? previewPanel.left : parent.right; top: tabStrip.bottom; bottom: parent.bottom
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
            actions: win.actions
            keysFor: a => win.keysFor(a)
            opacity: win.settingsOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - settingsPage.opacity) * 10 }
            anchors { left: dock.right; right: parent.right; top: tabStrip.bottom; bottom: parent.bottom; margins: 6; leftMargin: 4; topMargin: 2 }
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
    QuickOpen {
        id: quickOpen
        ops: fileOps
        onNavigate: path => { win.settingsOpen = false; win.nav.go(path) }
        onReveal: path => { win.settingsOpen = false; win.tab.reveal(path) }
        onClosed: win.focusView()
    }
    CommandPalette {
        id: palette
        actions: win.actions
        keysFor: a => win.keysFor(a)
        // configurações também viram comandos
        extra: {
            const out = []
            for (const p of settingsPage.pages)
                out.push({ id: "settings:" + p.id, label: "Configurações: " + p.label, group: "Configurações",
                           run: () => { settingsPage.openPage(p.id); win.settingsOpen = true } })
            for (const t of [["dark", "Escuro"], ["light", "Claro"], ["auto", "Automático"]])
                out.push({ id: "theme:" + t[0], label: "Tema: " + t[1], group: "Aparência", run: () => Settings.theme = t[0] })
            for (const m of [["auto", "Pela largura"], ["autohide", "Some sozinha"], ["full", "Cheia"], ["compact", "Ícones"], ["hidden", "Oculta"]])
                out.push({ id: "sidebarMode:" + m[0], label: "Barra lateral: " + m[1], group: "Aparência", run: () => Settings.sidebarMode = m[0] })
            for (const i of [["duotone", "Duotone"], ["mac", "macOS"], ["outline", "Contorno"], ["flat", "Plano"], ["system", "Sistema"]])
                out.push({ id: "icons:" + i[0], label: "Ícones dos arquivos: " + i[1], group: "Aparência", run: () => Settings.fileIcons = i[0] })
            out.push({ id: "toggle:singleClick", label: (Settings.singleClick ? "Desligar" : "Ligar") + " abrir com um clique", group: "Comportamento",
                       run: () => Settings.singleClick = !Settings.singleClick })
            out.push({ id: "toggle:reduceMotion", label: (Settings.reduceMotion ? "Ligar" : "Desligar") + " animações", group: "Animações",
                       run: () => Settings.reduceMotion = !Settings.reduceMotion })
            out.push({ id: "toggle:swipe", label: (Settings.swipeNavigation ? "Desligar" : "Ligar") + " gestos do touchpad", group: "Gestos",
                       run: () => Settings.swipeNavigation = !Settings.swipeNavigation })
            return out
        }
        onClosed: win.focusView()
    }
    ConnectDialog { id: connectDialog; ops: fileOps }
    PropertiesDialog { id: propertiesDialog; ops: fileOps }
    OpenWithDialog { id: openWithDialog; ops: fileOps }

    // ── atalhos (desativados durante edição de texto/diálogos) ──
    readonly property bool typing: (fm && fm.renamingPath !== "") || (header.search !== null && header.search.active)
                                   || confirmDialog.opened || conflictDialog.opened || promptDialog.opened
                                   || propertiesDialog.opened || openWithDialog.opened || connectDialog.opened || settingsOpen
    readonly property bool ready: fm !== null && !typing
    readonly property bool writable: ready && !fm.isTrash && !fm.path.startsWith("folio:") // pasta de verdade (colar, criar)

    // ── ações: alimentam os atalhos de teclado, a paleta de comandos (Ctrl+Shift+P) e Configurações → Atalhos ──
    // { id, label, group, keys (padrão), when() (disponível agora?), run() }
    readonly property var actions: [
        // Arquivos
        { id: "copy", label: "Copiar", group: "Arquivos", keys: ["Ctrl+C"], when: () => ready, run: () => fileOps.copy(fm.selectedPaths()) },
        { id: "cut", label: "Recortar", group: "Arquivos", keys: ["Ctrl+X"], when: () => ready && !fm.isTrash, run: () => fileOps.cut(fm.selectedPaths()) },
        { id: "paste", label: "Colar", group: "Arquivos", keys: ["Ctrl+V"], when: () => writable, run: () => fileOps.paste(fm.path) },
        { id: "undo", label: "Desfazer", group: "Arquivos", keys: ["Ctrl+Z"], when: () => ready, run: () => fileOps.undo() },
        { id: "trash", label: "Mover para a Lixeira", group: "Arquivos", keys: ["Delete"], when: () => ready, run: () => requestDelete(fm.selectedPaths(), false) },
        { id: "delete", label: "Excluir permanentemente", group: "Arquivos", keys: ["Shift+Delete"], when: () => ready, run: () => requestDelete(fm.selectedPaths(), true) },
        { id: "rename", label: "Renomear", group: "Arquivos", keys: ["F2"], when: () => ready && fm.selectedCount >= 1 && !fm.isTrash,
          run: () => fm.selectedCount === 1 ? fm.renamingPath = fm.selectedPaths()[0] : batchRename.show(fm.selectedPaths()) },
        { id: "newFolder", label: "Nova pasta", group: "Arquivos", keys: ["Ctrl+Shift+N"], when: () => writable, run: () => tab.newFolder() },
        { id: "newFile", label: "Novo arquivo", group: "Arquivos", keys: ["Ctrl+Alt+N"], when: () => writable, run: () => tab.newFile() },
        { id: "properties", label: "Propriedades", group: "Arquivos", keys: ["Alt+Return", "Ctrl+I"], when: () => ready,
          run: () => showProperties(fm.selectedPaths().length ? fm.selectedPaths() : [fm.path]) },
        { id: "copyPath", label: "Copiar caminho", group: "Arquivos", keys: ["Ctrl+Shift+C"], when: () => ready,
          run: () => fileOps.copyText(fm.selectedPaths().length ? fm.selectedPaths().join("\n") : fm.path) },
        { id: "itemMenu", label: "Menu de contexto dos itens", group: "Arquivos", keys: ["Shift+F10", "Menu"], when: () => ready && fm.selectedCount > 0, run: () => tab.view.openItemMenu() },
        { id: "quickLook", label: "Visualização Rápida", group: "Arquivos", keys: ["Space"], when: () => ready,
          run: () => quickLook.shown ? quickLook.shown = false : openQuickLook() },
        { id: "terminal", label: "Abrir terminal aqui", group: "Arquivos", keys: ["F4"], when: () => fm !== null && !fm.isTrash,
          run: () => { const sel = fm.selectedPaths(); fileOps.openTerminal(fm.isSearch && sel.length > 0 ? fileOps.parentDir(sel[0]) : fm.path) } },
        { id: "addFavorite", label: "Adicionar pasta aos Favoritos", group: "Arquivos", keys: ["Ctrl+D"], when: () => writable, run: () => placesModel.addFavorite(fm.path) },
        // Seleção
        { id: "selectAll", label: "Selecionar tudo", group: "Seleção", keys: ["Ctrl+A"], when: () => ready, run: () => fm.selectAll() },
        { id: "invertSelection", label: "Inverter seleção", group: "Seleção", keys: ["Ctrl+Shift+I"], when: () => ready, run: () => fm.invertSelection() },
        { id: "selectPattern", label: "Selecionar por padrão…", group: "Seleção", keys: ["Ctrl+S"], when: () => ready, run: () => promptSelectPattern() },
        // Navegação
        { id: "back", label: "Voltar", group: "Navegação", keys: ["Alt+Left", "Backspace"], when: () => ready, run: () => nav.back() },
        { id: "forward", label: "Avançar", group: "Navegação", keys: ["Alt+Right"], when: () => ready, run: () => nav.forward() },
        { id: "up", label: "Pasta acima", group: "Navegação", keys: ["Alt+Up"], when: () => ready, run: () => nav.up() },
        { id: "homeDir", label: "Ir para a pasta pessoal", group: "Navegação", keys: ["Alt+Home"], when: () => ready, run: () => nav.go("~") },
        { id: "homePage", label: "Ir para o Início", group: "Navegação", keys: [], when: () => ready, run: () => nav.go("folio:home") },
        { id: "recent", label: "Ir para Recentes", group: "Navegação", keys: [], when: () => ready, run: () => nav.go("folio:recent") },
        { id: "trashDir", label: "Ir para a Lixeira", group: "Navegação", keys: [], when: () => ready, run: () => nav.go(fileOps.trashDir) },
        { id: "reload", label: "Recarregar", group: "Navegação", keys: ["F5", "Ctrl+R"], when: () => ready, run: () => fm.reload() },
        { id: "editPath", label: "Digitar caminho", group: "Navegação", keys: ["Ctrl+L"], when: () => fm !== null, run: () => { if (header.item) header.item.pathBar.edit() } },
        { id: "search", label: "Buscar na pasta", group: "Navegação", keys: ["Ctrl+F"], when: () => fm !== null, run: () => { if (header.search) header.search.focusField() } },
        { id: "quickOpen", label: "Busca rápida de arquivos", group: "Navegação", keys: ["Ctrl+P"], when: () => tab !== null, run: () => quickOpen.show() },
        { id: "palette", label: "Paleta de comandos", group: "Navegação", keys: ["Ctrl+Shift+P"], when: () => true, run: () => palette.show() },
        // Vista
        { id: "viewGrid", label: "Vista em ícones", group: "Vista", keys: ["Ctrl+1"], when: () => ready, run: () => fm.viewMode = "grid" },
        { id: "viewList", label: "Vista em lista", group: "Vista", keys: ["Ctrl+2"], when: () => ready, run: () => fm.viewMode = "list" },
        { id: "viewColumns", label: "Vista em colunas", group: "Vista", keys: ["Ctrl+3"], when: () => ready, run: () => fm.viewMode = "column" },
        { id: "hidden", label: "Mostrar/ocultar arquivos ocultos", group: "Vista", keys: ["Ctrl+H"], when: () => ready, run: () => fm.showHidden = !fm.showHidden },
        { id: "extensions", label: "Mostrar/ocultar extensões", group: "Vista", keys: ["Ctrl+E"], when: () => ready, run: () => fm.showExtensions = !fm.showExtensions },
        { id: "preview", label: "Painel de prévia", group: "Vista", keys: ["F3"], when: () => true, run: () => Settings.previewPanel = !Settings.previewPanel },
        { id: "sidebar", label: "Mostrar/esconder barra lateral", group: "Vista", keys: ["Ctrl+B", "F9"], when: () => true, run: () => toggleSidebar() },
        { id: "zoomIn", label: "Aumentar ícones", group: "Vista", keys: ["Ctrl+=", "Ctrl++"], when: () => true, run: () => zoom(8) },
        { id: "zoomOut", label: "Diminuir ícones", group: "Vista", keys: ["Ctrl+-"], when: () => true, run: () => zoom(-8) },
        { id: "zoomReset", label: "Tamanho padrão dos ícones", group: "Vista", keys: ["Ctrl+0"], when: () => true, run: () => Settings.iconSize = 76 },
        { id: "fullscreen", label: "Tela cheia", group: "Vista", keys: ["F11"], when: () => true, run: () => toggleFullscreen() },
        // Janela e abas
        { id: "newTab", label: "Nova aba", group: "Janela e abas", keys: ["Ctrl+T"], when: () => true, run: () => newTab(fm ? fm.path : fileOps.startPath()) },
        { id: "closeTab", label: "Fechar aba", group: "Janela e abas", keys: ["Ctrl+W"], when: () => true, run: () => tabStrip.requestClose(currentTab) },
        { id: "nextTab", label: "Próxima aba", group: "Janela e abas", keys: ["Ctrl+Tab"], when: () => tabs.count > 1, run: () => selectTab((currentTab + 1) % tabs.count) },
        { id: "prevTab", label: "Aba anterior", group: "Janela e abas", keys: ["Ctrl+Shift+Tab"], when: () => tabs.count > 1, run: () => selectTab((currentTab - 1 + tabs.count) % tabs.count) },
        { id: "split", label: "Dividir janela", group: "Janela e abas", keys: ["Ctrl+\\", "F6"], when: () => true, run: () => toggleSplit() },
        { id: "newWindow", label: "Nova janela", group: "Janela e abas", keys: ["Ctrl+N"], when: () => true, run: () => fileOps.openNewWindow(fm ? fm.path : fileOps.startPath()) },
        { id: "settings", label: "Configurações", group: "Janela e abas", keys: ["Ctrl+,"], when: () => true, run: () => settingsOpen = !settingsOpen },
        { id: "quit", label: "Sair", group: "Janela e abas", keys: ["Ctrl+Q"], when: () => true, run: () => win.close() }
    ]
    // teclas em uso: as trocadas nas Configurações ou as padrão
    function keysFor(action) {
        const custom = Settings.shortcuts[action.id]
        return custom !== undefined ? custom : action.keys
    }
    function runAction(id) {
        const a = actions.find(x => x.id === id)
        if (a && a.when()) a.run()
    }

    Shortcut { sequence: "Escape"; enabled: quickLook.shown; onActivated: quickLook.shown = false }
    Shortcut { sequence: "Escape"; enabled: win.sidebarRevealed && !quickLook.shown; onActivated: win.sidebarRevealed = false }
    Shortcut { sequence: "Escape"; enabled: win.settingsOpen && settingsPage.query === "" && settingsPage.recording === ""; onActivated: win.settingsOpen = false }

    Instantiator {
        model: win.actions
        delegate: Shortcut {
            required property var modelData
            sequences: win.keysFor(modelData)
            enabled: sequences.length > 0 && settingsPage.recording === "" && modelData.when()
            onActivated: modelData.run()
        }
    }
}
