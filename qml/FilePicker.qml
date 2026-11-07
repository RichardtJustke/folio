import QtCore as Core
import QtQuick
import QtQuick.Controls
import Folio

// Seletor de arquivos do Folio para outros apps ("Abrir", "Salvar como", escolher pasta),
// aberto pelo xdg-desktop-portal (folio --portal). Usa a mesma grade, ícones e miniaturas do Folio.
Window {
    id: win

    // ── pedido ──
    property string mode: "open"        // open | save | saveFiles | dir
    property string requestTitle: ""
    property string acceptLabel: ""
    property bool multiple: false
    property var filters: []            // [{name, patterns: ["*.png", "mime:image/png"]}]
    property int currentFilter: -1
    property string currentName: ""
    property string startDir: ""
    property var saveNames: []          // saveFiles: nomes dos arquivos que o app vai gravar
    signal finished(bool ok, var paths)

    readonly property bool saving: mode === "save" || mode === "saveFiles"
    readonly property bool picksDir: mode === "dir" || mode === "saveFiles"
    property var picked: []             // arquivos ativados (duplo clique / Enter) num ciclo
    property string overwrite: ""       // caminho que já existe, aguardando confirmação
    property bool done: false

    width: 960
    height: 620
    minimumWidth: 480
    minimumHeight: 360
    visible: true
    color: "transparent"
    flags: Qt.Dialog | Qt.FramelessWindowHint
    title: requestTitle || (saving ? "Salvar" : mode === "dir" ? "Escolher pasta" : "Abrir")

    Core.Settings {
        id: memory
        category: "picker"
        property string lastDir: ""
        property string viewMode: "grid"
    }

    function finish(ok, paths) {
        if (done) return
        done = true
        if (ok && paths.length > 0) memory.lastDir = fm.path
        memory.viewMode = fm.viewMode
        finished(ok, paths)
    }

    function join(dir, name) { return dir === "/" ? "/" + name : dir + "/" + name }

    readonly property var selectedFiles: fm.selectionRevision >= 0 ? fm.selectedPaths() : []
    readonly property bool canAccept: {
        if (mode === "save") return nameField.text.trim() !== "" && !fm.path.startsWith("folio:")
        if (picksDir) return !fm.path.startsWith("folio:")
        return selectedFiles.length > 0 && selectedFiles.every(p => !ops.resolveDir(p))
    }

    function accept() {
        if (!canAccept) return
        if (mode === "open") return finish(true, selectedFiles)
        if (mode === "dir") {
            const sel = selectedFiles.length === 1 && ops.resolveDir(selectedFiles[0]) ? selectedFiles[0] : fm.path
            return finish(true, [sel])
        }
        if (mode === "saveFiles") return finish(true, saveNames.map(n => join(fm.path, n)))
        // save: nome pode trazer "~/x/arq.txt" ou "sub/arq.txt"
        let name = nameField.text.trim()
        let path = name.startsWith("/") || name.startsWith("~") ? name : join(fm.path, name)
        path = path.replace(/^~/, Settings.home)
        if (ops.resolveDir(path)) { nav.go(path); nameField.text = currentName.split("/").pop(); return }
        if (overwrite !== path && ops.exists(path)) {
            overwrite = path
            return
        }
        finish(true, [path])
    }

    function activate(entry) {
        if (entry.isDir) { nav.go(entry.path); return }
        if (mode === "open") {
            picked = picked.concat([entry.path])
            Qt.callLater(() => { if (picked.length) { const p = picked; picked = []; finish(true, multiple ? p : [p[0]]) } })
        } else if (mode === "save") {
            nameField.text = entry.name
            accept()
        }
    }

    function applyFilter(i) {
        currentFilter = i
        fm.nameFilters = i >= 0 && i < filters.length ? filters[i].patterns : []
    }

    onClosing: finish(false, [])

    FileOps { id: ops }
    PlacesModel { id: places }
    Navigator { id: nav }
    FileModel {
        id: fm
        columns: grid.columns
        dirsOnly: win.picksDir
        Component.onCompleted: viewMode = memory.viewMode
    }
    Connections {
        target: nav
        function onCurrentPathChanged() {
            fm.path = nav.currentPath
            fm.selectPath(nav.lastLeft)
            win.overwrite = ""
        }
    }
    Connections {
        target: fm
        function onSelectionRevisionChanged() {
            // salvar: clicar num arquivo usa o nome dele
            if (win.mode === "save" && win.selectedFiles.length === 1 && !ops.resolveDir(win.selectedFiles[0]))
                nameField.text = win.selectedFiles[0].split("/").pop()
        }
    }

    Component.onCompleted: {
        const first = [startDir, memory.lastDir].find(d => d && ops.resolveDir(d)) || Settings.home
        nav.reset(ops.resolveDir(first) || first)
        applyFilter(currentFilter >= 0 ? currentFilter : (filters.length > 0 ? 0 : -1))
        nameField.text = currentName
        if (saving) {
            nameField.forceActiveFocus()
            // seleciona o nome sem a extensão, como no renomear
            const dot = currentName.lastIndexOf(".")
            nameField.select(0, dot > 0 ? dot : currentName.length)
        } else {
            grid.forceActiveFocus()
        }
    }

    Shortcut { sequence: "Esc"; onActivated: win.overwrite !== "" ? win.overwrite = "" : win.finish(false, []) }
    Shortcut { sequence: "Alt+Up"; onActivated: nav.up() }
    Shortcut { sequence: "Alt+Left"; onActivated: nav.back() }
    Shortcut { sequence: "Backspace"; enabled: !nameField.activeFocus && !pathBar.editing; onActivated: nav.up() }
    Shortcut { sequence: "Ctrl+H"; onActivated: fm.showHidden = !fm.showHidden }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathBar.editing = true }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.windowBg
        border.width: 1
        border.color: Theme.border

        // ── barra lateral ──
        Rectangle {
            id: side
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
            width: 190
            radius: Theme.radius - 6
            color: Theme.sidebarBg

            Text {
                id: heading
                anchors { left: parent.left; leftMargin: 14; top: parent.top; topMargin: 16; right: parent.right; rightMargin: 10 }
                text: win.title
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            ListView {
                anchors { left: parent.left; right: parent.right; top: heading.bottom; topMargin: 14; bottom: parent.bottom; margins: 6 }
                clip: true
                model: ops.quickDirs()
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 32; radius: 8
                    color: fm.path === modelData.path ? Theme.selected : placeArea.containsMouse ? Theme.hover : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 9
                        Image {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(32, 32)
                            source: Theme.icon(modelData.icon + ",folder-symbolic", Theme.sidebarIcon)
                        }
                        Text {
                            width: parent.width - 36
                            text: modelData.name
                            color: Theme.text
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: placeArea; anchors.fill: parent; hoverEnabled: true; onClicked: nav.go(modelData.path) }
                }
            }
        }

        // ── topo ──
        Item {
            id: header
            anchors { left: side.right; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 10 }
            height: Theme.headerHeight

            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

            Row {
                id: navButtons
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 4
                ToolIcon { icon: "go-previous-symbolic"; enabled: nav.canGoBack; tip: "Voltar"; onClicked: nav.back() }
                ToolIcon { icon: "go-up-symbolic"; enabled: nav.canGoUp; tip: "Pasta acima"; onClicked: nav.up() }
            }

            PathBar {
                id: pathBar
                anchors { left: navButtons.right; leftMargin: 10; right: tools.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                path: fm.path
                title: fm.title
                special: fm.path.startsWith("folio:")
                ops: ops
                onNavigate: p => nav.go(p)
                onSubmitted: typed => { const d = ops.resolveDir(typed); if (d) nav.go(d) }
            }

            Row {
                id: tools
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                ToolIcon {
                    icon: "folder-new-symbolic"
                    tip: "Nova pasta"
                    visible: win.saving || win.mode === "dir"
                    onClicked: { const p = ops.createFolder(fm.path); if (p) { fm.selectPath(p); fm.renamingPath = p } }
                }
                ToolIcon {
                    icon: fm.showHidden ? "view-reveal-symbolic" : "view-conceal-symbolic"
                    tip: "Arquivos ocultos (Ctrl+H)"
                    onClicked: fm.showHidden = !fm.showHidden
                }
                ToolIcon {
                    icon: fm.viewMode === "list" ? "view-grid-symbolic" : "view-list-symbolic"
                    tip: fm.viewMode === "list" ? "Ícones" : "Lista"
                    onClicked: fm.viewMode = fm.viewMode === "list" ? "grid" : "list"
                }
            }
        }

        // ── arquivos ──
        Rectangle {
            id: content
            anchors { left: side.right; right: parent.right; top: header.bottom; bottom: footer.top; leftMargin: 8; rightMargin: 8 }
            radius: Theme.radius - 8
            color: Theme.contentBacking
            clip: true

            FileGrid {
                id: grid
                anchors.fill: parent
                fileModel: fm
                ops: ops
                places: places
                focus: true
                onActivate: entry => win.activate(entry)
                onEnterArchive: path => {}
                onNewFolder: { const p = ops.createFolder(fm.path); if (p) { fm.selectPath(p); fm.renamingPath = p } }
                onNewFile: {}
                onOpenInNewTab: path => nav.go(path)
                onRevealInFolder: path => { nav.go(ops.parentDir(path)); fm.selectPath(path) }
                onRequestDelete: (paths, permanent) => {}
                onShowProperties: paths => {}
                onOpenWith: paths => {}
                onTransferTo: (paths, move) => {}
                onOpenTerminalHere: dir => ops.openTerminal(dir)
            }
        }

        // ── rodapé ──
        Item {
            id: footer
            anchors { left: side.right; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 12 }
            height: win.overwrite !== "" ? 92 : 56

            Text {
                visible: win.overwrite !== ""
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                text: "“" + win.overwrite.split("/").pop() + "” já existe. Salvar de novo substitui o arquivo."
                color: Theme.danger
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }

            Row {
                id: left
                anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 12 }
                spacing: 8

                TextField {
                    id: nameField
                    visible: win.mode === "save"
                    width: Math.min(360, footer.width - buttons.width - filterPill.width - 40)
                    height: 30
                    placeholderText: "Nome do arquivo"
                    placeholderTextColor: Theme.textFaint
                    color: Theme.text
                    font.pixelSize: Theme.fontSize
                    selectionColor: Theme.accent
                    leftPadding: 12
                    background: Rectangle { radius: 15; color: Theme.pillBg; border.width: 1; border.color: nameField.activeFocus ? Theme.accent : Theme.border }
                    onTextEdited: win.overwrite = ""
                    Keys.onReturnPressed: win.accept()
                    Keys.onEnterPressed: win.accept()
                    Keys.onDownPressed: grid.forceActiveFocus()
                }

                Text {
                    visible: win.mode === "saveFiles"
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.saveNames.length + (win.saveNames.length === 1 ? " arquivo será salvo nesta pasta" : " arquivos serão salvos nesta pasta")
                    color: Theme.textDim
                    font.pixelSize: 12
                }

                Rectangle {
                    id: filterPill
                    visible: win.filters.length > 0 && !win.picksDir
                    width: Math.min(240, Math.max(120, filterText.implicitWidth + 40)); height: 30; radius: 15
                    color: filterArea.containsMouse ? Theme.hover : Theme.pillBg
                    border.width: 1; border.color: Theme.border
                    Text {
                        id: filterText
                        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
                        text: win.currentFilter >= 0 && win.currentFilter < win.filters.length ? win.filters[win.currentFilter].name : "Todos os arquivos"
                        color: Theme.text
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Image {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 12; height: 12
                        sourceSize: Qt.size(24, 24)
                        source: Theme.icon("pan-down-symbolic,go-down-symbolic", Theme.textDim)
                    }
                    MouseArea { id: filterArea; anchors.fill: parent; hoverEnabled: true; onClicked: filterMenu.popup() }
                    GlassMenu {
                        id: filterMenu
                        Repeater {
                            model: win.filters
                            GlassMenuItem {
                                required property var modelData
                                required property int index
                                text: modelData.name
                                tick: index === win.currentFilter
                                onTriggered: win.applyFilter(index)
                            }
                        }
                    }
                }
            }

            Row {
                id: buttons
                anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 13 }
                spacing: 8
                DialogButton { text: "Cancelar"; onClicked: win.finish(false, []) }
                DialogButton {
                    primary: true
                    destructive: win.overwrite !== ""
                    opacity: win.canAccept ? 1 : 0.45
                    text: win.overwrite !== "" ? "Substituir"
                        : win.acceptLabel ? win.acceptLabel.replace(/_/g, "")
                        : win.saving ? "Salvar" : win.mode === "dir" ? "Escolher pasta" : "Abrir"
                    onClicked: win.accept()
                }
            }
        }
    }

    component ToolIcon: Rectangle {
        id: tb
        property string icon
        property string tip
        signal clicked
        width: 32; height: 32; radius: 16
        color: tbArea.containsMouse && enabled ? Theme.hover : "transparent"
        opacity: enabled ? 1 : 0.35
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Theme.icon(tb.icon, Theme.text)
        }
        MouseArea { id: tbArea; anchors.fill: parent; hoverEnabled: true; onClicked: tb.clicked() }
        ToolTip.visible: tbArea.containsMouse && tip !== ""
        ToolTip.text: tip
        ToolTip.delay: 600
    }
}
