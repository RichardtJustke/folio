import QtQuick
import QtQuick.Controls
import Folio

// Vista de arquivos: grade (ícones) ou lista, agrupada por data, virtualizada por linhas.
Item {
    id: root

    required property FileModel fileModel
    required property FileOps ops
    required property PlacesModel places

    readonly property bool listMode: fileModel.viewMode === "list"
    readonly property bool columnMode: fileModel.viewMode === "column"
    readonly property bool showLocation: fileModel.isSearch && fileModel.searchRecursive
    readonly property int hMargin: 14
    readonly property int columns: listMode || columnMode ? 1 : Math.max(1, Math.floor(list.width / Theme.tileWidth))
    readonly property real cellWidth: list.width / columns
    readonly property real rowHeight: listMode ? Theme.listRowHeight : Theme.tileHeight

    // colunas da lista
    readonly property real dateWidth: 132
    readonly property real sizeWidth: 84
    readonly property real typeWidth: Math.min(200, Math.max(110, list.width * 0.2))
    readonly property real nameWidth: Math.max(160, list.width - dateWidth - sizeWidth - typeWidth)

    readonly property var selection: fileModel.selectionRevision >= 0 ? fileModel.selectedPaths() : []
    readonly property var currentEntry: fileModel.selectionRevision >= 0 && fileModel.revision >= 0 ? fileModel.entry(fileModel.currentIndex) : ({})
    readonly property bool singleDir: selection.length === 1 && currentEntry.isDir === true

    signal activate(var entry)
    signal enterArchive(string path)
    signal newFolder
    signal openInNewTab(string path)
    signal revealInFolder(string path)
    signal requestDelete(var paths, bool permanent)
    signal requestEmptyTrash
    signal quickLook
    signal newFile
    signal showProperties(var paths)
    signal openWith(string path)
    signal renameMany(var paths)
    signal promptSelectPattern
    signal openTerminalHere(string dir)

    function openItemMenu() { itemMenu.popup() }

    // ── animações dos itens ──
    // posições dos itens destruídos na última reconstrução da lista (path → {x, y, t}), para os vizinhos deslizarem
    property var lastPos: ({})
    property var liveTiles: ({}) // path → FileInteraction vivo
    property bool settled: false // só anima depois que a pasta terminou de carregar

    function registerTile(fx) {
        liveTiles[fx.entry.path] = fx
        Qt.callLater(settleTile, fx)
    }

    function unregisterTile(fx) {
        try {
            const path = fx.entry.path
            if (liveTiles[path] === fx) delete liveTiles[path]
            if (fx.parent && list.contentItem) {
                const p = fx.mapToItem(list.contentItem, 0, 0)
                lastPos[path] = { x: p.x, y: p.y, t: Date.now() }
            }
        } catch (e) {}
    }

    function settleTile(fx) {
        if (!fx || !fx.parent || !root.settled || fileModel.searchQuery !== "") return
        const path = fx.entry.path
        const p = fx.mapToItem(list.contentItem, 0, 0)
        const old = lastPos[path]
        if (old && Date.now() - old.t < 500) {
            const dx = old.x - p.x, dy = old.y - p.y
            if (Math.abs(dx) > 2 || Math.abs(dy) > 2) fx.slideFrom(dx, dy)
            return
        }
        const order = fileModel.freshIndex(path)
        if (order >= 0) fx.pop(order)
    }

    // centro (em coordenadas da janela) e entrada de cada caminho visível — origem das animações de voo
    function ghostItems(paths) {
        const out = []
        for (const p of paths) {
            const fx = liveTiles[p]
            if (!fx || !fx.parent) continue
            const c = fx.mapToItem(null, fx.width / 2, root.listMode ? fx.height / 2 : Theme.iconSize / 2 + 12)
            out.push({ entry: fx.entry, x: c.x, y: c.y, size: root.listMode ? 22 : Theme.iconSize })
        }
        return out
    }

    function visiblePaths() { return Object.keys(liveTiles) }

    // imagem do arraste (pilha + quantidade); done(url) recebe a captura
    function dragImage(entry, done) {
        dragGhost.render(entry, fileModel.selectedEntries(3), fileModel.selectedCount, done)
    }
    DragGhost { id: dragGhost }

    function shake(paths) {
        for (const p of paths) { const fx = liveTiles[p]; if (fx) fx.shake() }
    }

    // ── troca de pasta: o conteúdo desliza 16px na direção do movimento ──
    property string prevPath: ""
    property int navDir: 0
    property bool navPending: false
    Translate { id: navShift }
    ParallelAnimation {
        id: navAnim
        NumberAnimation { target: navShift; property: "x"; to: 0; duration: Theme.dur(220); easing.type: Easing.OutCubic }
        NumberAnimation { target: list; property: "opacity"; to: 1; duration: Theme.dur(220); easing.type: Easing.OutCubic }
    }
    Timer {
        id: settleTimer
        interval: 280
        onTriggered: root.settled = true
    }
    Connections {
        target: root.fileModel
        function onEntriesChanged() {
            if (root.navPending) {
                root.navPending = false
                if (Theme.motion) {
                    navShift.x = 16 * root.navDir
                    list.opacity = 0
                    navAnim.restart()
                }
            }
            if (!root.settled) settleTimer.restart()
        }
        function onPathChanged() {
            const np = root.fileModel.path
            root.navDir = np.startsWith(root.prevPath + "/") ? 1 : root.prevPath.startsWith(np + "/") ? -1 : 0
            root.prevPath = np
            root.settled = false
            root.lastPos = ({})
            root.navPending = true
        }
        function onColumnsChanged() { root.settled = false; settleTimer.restart() }
        function onViewModeChanged() { root.settled = false; root.lastPos = ({}); settleTimer.restart() }
    }
    Component.onCompleted: prevPath = fileModel.path

    function handleDrop(drop, dest) {
        if (!drop.hasUrls) return
        ops.dropUrls(drop.urls, dest)
        drop.accept(Qt.CopyAction) // a operação é feita aqui; a origem não deve apagar nada
    }

    function commitRename(path, name) {
        const p = ops.rename(path, name)
        fileModel.renamingPath = ""
        if (p) fileModel.selectPath(p)
        root.forceActiveFocus()
    }

    function cancelRename() {
        fileModel.renamingPath = ""
        root.forceActiveFocus()
    }

    function ensureCurrentVisible() {
        const row = fileModel.rowOfIndex(fileModel.currentIndex)
        if (row >= 0) list.positionViewAtIndex(row, ListView.Contain)
    }

    function openSelection() {
        const paths = fileModel.selectedPaths()
        if (paths.length === 0 && fileModel.currentIndex >= 0) {
            root.activate(fileModel.entry(fileModel.currentIndex))
            return
        }
        for (let i = 0; i < fileModel.count; i++)
            if (fileModel.isSelected(i)) root.activate(fileModel.entry(i))
    }

    Connections {
        target: root.fileModel
        function onCurrentIndexChanged() { Qt.callLater(root.ensureCurrentVisible) }
        function onPathChanged() { list.positionViewAtBeginning() }
    }

    Keys.onPressed: e => {
        const shift = e.modifiers & Qt.ShiftModifier
        switch (e.key) {
        case Qt.Key_Left: if (!listMode) fileModel.moveCurrent(-1, shift); break
        case Qt.Key_Right: if (!listMode) fileModel.moveCurrent(1, shift); break
        case Qt.Key_Up: fileModel.moveRow(-1, shift); break
        case Qt.Key_Down: fileModel.moveRow(1, shift); break
        case Qt.Key_Home: fileModel.select(0, shift); break
        case Qt.Key_End: fileModel.select(fileModel.count - 1, shift); break
        case Qt.Key_Return:
        case Qt.Key_Enter: root.openSelection(); break
        case Qt.Key_Escape: fileModel.clearSelection(); break
        default: return
        }
        e.accepted = true
    }

    // soltar no vazio = para a pasta atual
    DropArea {
        anchors.fill: parent
        enabled: !root.fileModel.isSearch
        onDropped: d => root.handleDrop(d, root.fileModel.path)
    }

    ListHeader {
        id: listHeader
        visible: root.listMode
        height: root.listMode ? 28 : 0
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.hMargin; rightMargin: root.hMargin }
        view: root
        fileModel: root.fileModel
    }

    ListView {
        id: list
        visible: !root.columnMode
        anchors { left: parent.left; right: parent.right; top: listHeader.bottom; bottom: parent.bottom; leftMargin: root.hMargin; rightMargin: root.hMargin }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        transform: navShift
        cacheBuffer: 600
        model: root.fileModel.rows
        topMargin: 4
        bottomMargin: 16

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, sb.pressed ? 0.45 : 0.25)
                opacity: sb.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }

        // fundo: limpa seleção, menu de contexto e seleção por retângulo
        MouseArea {
            id: bg

            property point start
            property point cur
            property bool banding: false
            property real lastY: 0

            parent: list
            anchors.fill: parent
            z: -1
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            function toContent(x, y) { return Qt.point(x, y + list.contentY - list.originY) }
            function update() {
                root.fileModel.updateRubberBand(start.x, start.y, cur.x, cur.y,
                                                Theme.sectionHeaderHeight, root.rowHeight, root.cellWidth)
            }

            onPressed: e => {
                root.forceActiveFocus()
                if (e.button === Qt.RightButton) {
                    root.fileModel.clearSelection()
                    bgMenu.popup()
                    return
                }
                const additive = e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)
                if (!additive) root.fileModel.clearSelection()
                start = toContent(e.x, e.y)
                cur = start
                root.fileModel.beginRubberBand(additive)
            }
            onPositionChanged: e => {
                if (!(pressedButtons & Qt.LeftButton)) return
                banding = true
                lastY = e.y
                cur = toContent(Math.max(0, Math.min(e.x, width - 1)), e.y)
                update()
                if (e.y < 0 || e.y > height) autoScroll.start()
                else autoScroll.stop()
            }
            onReleased: { banding = false; autoScroll.stop() }
            onCanceled: { banding = false; autoScroll.stop() }

            Timer {
                id: autoScroll
                interval: 16
                repeat: true
                onTriggered: {
                    const step = bg.lastY < 0 ? Math.max(-30, bg.lastY / 2) : Math.min(30, (bg.lastY - bg.height) / 2)
                    const maxY = list.originY + Math.max(0, list.contentHeight + list.bottomMargin - list.height)
                    list.contentY = Math.max(list.originY - list.topMargin, Math.min(maxY, list.contentY + step))
                    bg.cur = bg.toContent(bg.cur.x, bg.lastY)
                    bg.update()
                }
            }
        }

        Rectangle { // retângulo de seleção
            parent: list
            visible: bg.banding
            x: Math.min(bg.start.x, bg.cur.x)
            y: Math.min(bg.start.y, bg.cur.y) - list.contentY + list.originY
            width: Math.abs(bg.cur.x - bg.start.x)
            height: Math.abs(bg.cur.y - bg.start.y)
            color: Qt.rgba(0.04, 0.52, 1, 0.15)
            border.width: 1
            border.color: Theme.accent
            radius: 2
        }

        delegate: Loader {
            id: rowLoader
            required property string kind
            required property string title
            required property var items

            width: ListView.view.width
            sourceComponent: kind === "header" ? headerComp : root.listMode ? listComp : gridComp

            Component {
                id: headerComp
                SectionHeader { title: rowLoader.title }
            }
            Component {
                id: gridComp
                Row {
                    Repeater {
                        model: rowLoader.items
                        FileTile {
                            required property var modelData
                            entry: modelData
                            view: root
                            width: root.cellWidth
                            selected: root.fileModel.selectionRevision >= 0 && root.fileModel.isSelected(modelData.index)
                            renaming: root.fileModel.renamingPath === modelData.path
                        }
                    }
                }
            }
            Component {
                id: listComp
                FileListRow {
                    entry: rowLoader.items[0]
                    view: root
                    width: rowLoader.width
                    selected: root.fileModel.selectionRevision >= 0 && root.fileModel.isSelected(entry.index)
                    renaming: root.fileModel.renamingPath === entry.path
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.fileModel.loading && root.fileModel.count === 0 && !root.columnMode
        text: root.fileModel.error || (root.fileModel.isSearch ? "Nenhum resultado" : "Pasta vazia")
        color: Theme.textFaint
        font.pixelSize: 14
    }

    // ── vista em colunas (Miller columns) ──
    ColumnView {
        id: columnView
        visible: root.columnMode
        anchors.fill: parent
        fileModel: root.fileModel
        ops: root.ops
        places: root.places
        onActivate: entry => root.activate(entry)
        onOpenInNewTab: path => root.openInNewTab(path)
        onRequestDelete: (paths, permanent) => root.requestDelete(paths, permanent)
        onRequestEmptyTrash: root.requestEmptyTrash()
        onQuickLook: root.quickLook()
        onShowProperties: paths => root.showProperties(paths)
        onOpenWith: path => root.openWith(path)
        onRenameMany: paths => root.renameMany(paths)
        onPromptSelectPattern: root.promptSelectPattern()
        onOpenTerminalHere: dir => root.openTerminalHere(dir)
    }

    Text { // aviso de limite na busca
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
        visible: root.fileModel.count > 0 && root.fileModel.error !== ""
        text: root.fileModel.error
        color: Theme.textFaint
        font.pixelSize: 11
    }

    component Separator: MenuSeparator {
        contentItem: Rectangle { implicitHeight: 1; color: Theme.border }
    }

    GlassMenu {
        id: itemMenu
        GlassMenuItem { text: "Abrir"; onTriggered: root.openSelection() }
        GlassMenuItem {
            text: "Abrir em Nova Aba"
            visible: root.singleDir
            onTriggered: root.openInNewTab(root.selection[0])
        }
        GlassMenuItem {
            text: "Mostrar na Pasta"
            visible: root.showLocation && root.selection.length === 1
            onTriggered: root.revealInFolder(root.selection[0])
        }
        GlassMenuItem {
            text: "Entrar no arquivo"
            visible: root.selection.length === 1 && root.currentEntry.isArchive
            onTriggered: root.enterArchive(root.selection[0])
        }
        GlassMenuItem {
            text: "Extrair Aqui"
            visible: root.fileModel.path.includes("::")
            onTriggered: root.ops.extract(root.fileModel.path.section("::", 0, 0))
        }
        GlassMenuItem {
            text: "Abrir com…"
            visible: root.selection.length === 1 && !root.currentEntry.isDir && !root.fileModel.isTrash
            onTriggered: root.openWith(root.selection[0])
        }
        GlassMenuItem {
            text: "Abrir Terminal Aqui"
            visible: root.singleDir && !root.fileModel.isTrash
            onTriggered: root.openTerminalHere(root.selection[0])
        }
        GlassMenuItem { text: "Visualização Rápida"; onTriggered: root.quickLook() }
        Separator { visible: !root.fileModel.isTrash }
        TagMenuItem {
            visible: !root.fileModel.isTrash
            paths: root.selection
            ops: root.ops
            revision: root.fileModel.revision
            onChanged: root.fileModel.reload()
        }
        Separator {}
        GlassMenuItem {
            text: "Restaurar"
            visible: root.fileModel.isTrash
            onTriggered: root.ops.restoreFromTrash(root.selection)
        }
        GlassMenuItem {
            text: "Renomear…"
            shortcut: Theme.keyFor("rename", "F2")
            visible: !root.fileModel.isTrash
            onTriggered: root.selection.length === 1 ? root.fileModel.renamingPath = root.selection[0]
                                                      : root.renameMany(root.selection)
        }
        GlassMenuItem {
            text: "Duplicar"
            visible: !root.fileModel.isTrash
            onTriggered: root.ops.transfer(root.selection, root.fileModel.path, false)
        }
        GlassMenuItem {
            text: "Criar Link"
            visible: !root.fileModel.isTrash
            onTriggered: root.ops.makeLinks(root.selection)
        }
        GlassMenuItem {
            text: "Enviar por E-mail"
            visible: !root.fileModel.isTrash && root.selection.length > 0
            onTriggered: Qt.openUrlExternally("mailto:?subject=Arquivos&body=" + root.selection.join("%0D%0A"))
        }
        GlassMenuItem { text: "Copiar"; onTriggered: root.ops.copy(root.selection) }
        GlassMenuItem { text: "Recortar"; visible: !root.fileModel.isTrash; onTriggered: root.ops.cut(root.selection) }
        GlassMenuItem {
            text: "Colar na Pasta"
            visible: root.singleDir && !root.fileModel.isTrash
            enabled: root.ops.canPaste
            onTriggered: root.ops.paste(root.selection[0])
        }
        Separator {}
        GlassMenuItem {
            text: "Compactar em .zip"
            visible: !root.fileModel.isTrash && root.ops.canZip()
            onTriggered: root.ops.compress(root.selection, "zip")
        }
        GlassMenuItem {
            text: "Compactar em .tar.gz"
            visible: !root.fileModel.isTrash
            onTriggered: root.ops.compress(root.selection, "tar.gz")
        }
        GlassMenuItem {
            text: "Extrair Aqui"
            visible: root.selection.length === 1 && root.ops.isArchive(root.selection[0])
            onTriggered: root.ops.extract(root.selection[0])
        }
        Separator {}
        GlassMenuItem { text: "Copiar Caminho"; onTriggered: root.ops.copyText(root.selection.join("\n")) }
        GlassMenuItem { text: "Propriedades"; onTriggered: root.showProperties(root.selection) }
        Separator {}
        GlassMenuItem {
            text: "Adicionar aos Favoritos"
            visible: root.singleDir && !root.fileModel.isTrash && !root.places.isFavorite(root.selection[0])
            onTriggered: root.places.addFavorite(root.selection[0])
        }
        GlassMenuItem {
            text: "Mover para a Lixeira"
            visible: !root.fileModel.isTrash
            onTriggered: root.requestDelete(root.selection, false)
        }
        GlassMenuItem { text: "Excluir Permanentemente…"; onTriggered: root.requestDelete(root.selection, true) }
    }

    GlassMenu {
        id: bgMenu
        GlassMenuItem { text: "Nova Pasta"; visible: !root.fileModel.isTrash; onTriggered: root.newFolder() }
        GlassMenuItem { text: "Novo Arquivo"; visible: !root.fileModel.isTrash; onTriggered: root.newFile() }
        GlassMenuItem {
            text: "Novo Documento…"
            visible: !root.fileModel.isTrash
            onTriggered: newDocMenu.popup()
        }
        GlassMenuItem {
            text: "Colar"
            visible: !root.fileModel.isTrash
            enabled: root.ops.canPaste
            onTriggered: root.ops.paste(root.fileModel.path)
        }
        GlassMenuItem {
            text: root.ops.undoLabel || "Desfazer"
            enabled: root.ops.canUndo && !root.ops.busy
            onTriggered: root.ops.undo()
        }
        GlassMenuItem { text: "Esvaziar Lixeira…"; visible: root.fileModel.isTrash; onTriggered: root.requestEmptyTrash() }
        Separator {}
        GlassMenuItem { text: "Ícones"; tick: !root.listMode && !root.columnMode; onTriggered: root.fileModel.viewMode = "grid" }
        GlassMenuItem { text: "Lista"; tick: root.listMode; onTriggered: root.fileModel.viewMode = "list" }
        GlassMenuItem { text: "Colunas"; tick: root.columnMode; onTriggered: root.fileModel.viewMode = "column" }
        Separator {}
        GlassMenuItem { text: "Ordenar por Nome"; tick: root.fileModel.sortKey === "name"; onTriggered: root.fileModel.sortBy("name") }
        GlassMenuItem { text: "Ordenar por Data"; tick: root.fileModel.sortKey === "modified"; onTriggered: root.fileModel.sortBy("modified") }
        GlassMenuItem { text: "Ordenar por Tamanho"; tick: root.fileModel.sortKey === "size"; onTriggered: root.fileModel.sortBy("size") }
        GlassMenuItem { text: "Ordenar por Tipo"; tick: root.fileModel.sortKey === "type"; onTriggered: root.fileModel.sortBy("type") }
        GlassMenuItem {
            text: "Agrupar por Data"
            tick: root.fileModel.groupByDate
            onTriggered: root.fileModel.groupByDate = !root.fileModel.groupByDate
        }
        GlassMenuItem {
            text: "Mostrar Arquivos Ocultos"
            tick: root.fileModel.showHidden
            onTriggered: root.fileModel.showHidden = !root.fileModel.showHidden
        }
        GlassMenuItem {
            text: "Mostrar Extensões"
            tick: root.fileModel.showExtensions
            onTriggered: root.fileModel.showExtensions = !root.fileModel.showExtensions
        }
        Separator {}
        GlassMenuItem { text: "Selecionar Tudo"; onTriggered: root.fileModel.selectAll() }
        GlassMenuItem { text: "Inverter Seleção"; onTriggered: root.fileModel.invertSelection() }
        GlassMenuItem { text: "Selecionar por Padrão…"; onTriggered: root.promptSelectPattern() }
        Separator {}
        GlassMenuItem { text: "Abrir Terminal Aqui"; shortcut: Theme.keyFor("terminal", "F4"); onTriggered: root.ops.openTerminal(root.fileModel.path) }
        GlassMenuItem { text: "Copiar Caminho da Pasta"; onTriggered: root.ops.copyText(root.fileModel.path) }
        GlassMenuItem { text: "Propriedades"; onTriggered: root.showProperties([root.fileModel.path]) }
    }

    // templates de ~/Modelos: cria um documento novo a partir de um deles
    GlassMenu {
        id: newDocMenu
        title: "Novo Documento"
        GlassMenuItem {
            text: "Documento vazio"
            onTriggered: root.newFile()
        }
        Separator {}
        Repeater {
            model: root.ops ? root.ops.templates() : []
            GlassMenuItem {
                required property string modelData
                text: modelData.split("/").pop()
                onTriggered: {
                    const p = root.ops.newFromTemplate(modelData, root.fileModel.path)
                    if (p) root.fileModel.selectPath(p)
                }
            }
        }
    }
}
