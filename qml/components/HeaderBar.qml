import QtQuick
import QtQuick.Controls
import Folio

Item {
    id: root

    required property var window
    required property FileModel fileModel
    required property Navigator navigator
    required property FileOps ops

    property GitRepo git: null
    readonly property bool inRepo: !!git && git.active
    property alias search: searchField
    property alias pathBar: pathBar
    property bool sidebarHidden: false
    readonly property bool narrow: width < 700
    readonly property bool tiny: width < 460
    readonly property bool controlsLeft: Settings.windowControls === "left"
    readonly property bool controlsRight: Settings.windowControls === "right"

    signal toggleSidebar
    signal openSettings
    signal openPath(string path)
    signal topClicked

    signal customizeToolbar
    signal newBranch
    signal newFolder
    signal emptyTrash
    signal focusView

    height: Theme.headerHeight

    // arrastar / duplo clique para maximizar
    MouseArea {
        property point pressPos
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: e => {
            if (e.button === Qt.RightButton) { customizeMenu.popup(); return }
            pressPos = Qt.point(e.x, e.y); root.topClicked()
        }
        onPositionChanged: e => {
            // só vira "mover janela" depois de arrastar de verdade (permite duplo/triplo clique)
            if (pressed && Math.abs(e.x - pressPos.x) + Math.abs(e.y - pressPos.y) > 8) root.window.startSystemMove()
        }
    }

    GlassMenu {
        id: customizeMenu
        GlassMenuItem { text: "Personalizar Barra de Ferramentas…"; onTriggered: root.customizeToolbar() }
    }

    WindowControls {
        id: ctlLeft
        visible: root.controlsLeft
        window: root.window
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
    }

    ToolButton {
        id: sidebarBtn
        visible: root.sidebarHidden
        icon: "sidebar-show-symbolic,view-sidebar-symbolic,go-next-symbolic"
        anchors.left: ctlLeft.visible ? ctlLeft.right : parent.left
        anchors.leftMargin: 10
        onActivated: root.toggleSidebar()
    }

    NavPill {
        id: nav
        anchors {
            left: sidebarBtn.visible ? sidebarBtn.right : ctlLeft.visible ? ctlLeft.right : parent.left
            leftMargin: sidebarBtn.visible || ctlLeft.visible ? 8 : 14
            verticalCenter: parent.verticalCenter
        }
        canGoBack: root.navigator.canGoBack
        canGoForward: root.navigator.canGoForward
        onBack: root.navigator.back()
        onForward: root.navigator.forward()
    }

    PathBar {
        id: pathBar
        anchors { left: nav.right; leftMargin: 12; right: gitPill.visible ? gitPill.left : tools.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        path: root.fileModel.path
        title: root.fileModel.title
        special: root.fileModel.isTrash || root.fileModel.isSearch || root.fileModel.path.startsWith("folio:")
        ops: root.ops
        onNavigate: p => root.navigator.go(p)
        onSubmitted: typed => root.openPath(typed)
        onClosed: root.focusView()
    }

    component ToolButton: Rectangle {
        id: tb
        property string icon
        property string tip
        property bool checked
        signal activated

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 32; height: 32
        radius: 16
        color: checked ? Theme.selected : area.containsMouse ? Theme.hover : "transparent"
        border.width: checked ? 1 : 0
        border.color: Theme.border
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: tb.icon ? Theme.icon(tb.icon, Theme.text) : ""
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            ToolTip.visible: tb.tip !== "" && containsMouse
            ToolTip.text: tb.tip
            ToolTip.delay: 600
            onClicked: tb.activated()
        }
    }

    // { id: [ícone, dica, ação do Main.qml ou função] } — "view" e "sort" têm componente próprio
    readonly property var toolDefs: ({
        hidden: { icon: () => root.fileModel.showHidden ? "view-reveal-symbolic" : "view-conceal-symbolic", tip: "Arquivos ocultos", action: "hidden", checked: () => root.fileModel.showHidden },
        newFolder: { icon: () => "folder-new-symbolic", tip: "Nova pasta", action: "newFolder", visible: () => !root.fileModel.isTrash && !root.fileModel.path.startsWith("folio:") },
        preview: { icon: () => "view-dual-symbolic,view-sidebar-symbolic", tip: "Painel de prévia", action: "preview", checked: () => Settings.previewPanel },
        split: { icon: () => "view-split-symbolic", tip: "Dividir janela", action: "split" },
        newTab: { icon: () => "tab-new-symbolic", tip: "Nova aba", action: "newTab" },
        up: { icon: () => "go-up-symbolic", tip: "Pasta acima", action: "up", visible: () => root.navigator.canGoUp },
        reload: { icon: () => "view-refresh-symbolic", tip: "Recarregar", action: "reload" },
        home: { icon: () => "user-home-symbolic", tip: "Início", action: "homePage" },
        terminal: { icon: () => "utilities-terminal-symbolic", tip: "Abrir terminal aqui", action: "terminal" },
        palette: { icon: () => "system-run-symbolic", tip: "Paleta de comandos", action: "palette" },
        quickOpen: { icon: () => "system-search-symbolic", tip: "Busca rápida", action: "quickOpen" },
        copyPath: { icon: () => "edit-copy-symbolic", tip: "Copiar caminho", action: "copyPath" }
    })

    Component {
        id: actionButton
        ToolButton {
            readonly property string toolId: parent ? parent.modelData : ""
            readonly property var def: root.toolDefs[toolId]
            visible: !!def && (!def.visible || def.visible())
            icon: def ? def.icon() : ""
            checked: !!def && !!def.checked && def.checked()
            tip: def ? def.tip + (Theme.keyFor(def.action, "") ? " (" + Theme.keyFor(def.action, "") + ")" : "") : ""
            onActivated: root.window.runAction(def.action)
        }
    }

    Component {
        id: viewToggle
        Rectangle { // grade | lista
            width: 68; height: 32; radius: 16
            color: Theme.pillBg
            border.width: 1
            border.color: Theme.border
            Row {
                anchors.centerIn: parent
                ToolButton {
                    width: 32; height: 28
                    icon: "view-grid-symbolic"
                    checked: root.fileModel.viewMode === "grid"
                    onActivated: root.fileModel.viewMode = "grid"
                }
                ToolButton {
                    width: 32; height: 28
                    icon: "view-list-symbolic"
                    checked: root.fileModel.viewMode === "list"
                    onActivated: root.fileModel.viewMode = "list"
                }
            }
        }
    }

    Component {
        id: sortButton
        ToolButton {
            icon: root.fileModel.sortDescending ? "view-sort-descending-symbolic" : "view-sort-ascending-symbolic"
            tip: "Ordenar"
            onActivated: sortMenu.popup()
            GlassMenu {
                id: sortMenu
                GlassMenuItem { text: "Nome"; tick: root.fileModel.sortKey === "name"; onTriggered: root.fileModel.sortBy("name") }
                GlassMenuItem { text: "Data de Modificação"; tick: root.fileModel.sortKey === "modified"; onTriggered: root.fileModel.sortBy("modified") }
                GlassMenuItem { text: "Tamanho"; tick: root.fileModel.sortKey === "size"; onTriggered: root.fileModel.sortBy("size") }
                GlassMenuItem { text: "Tipo"; tick: root.fileModel.sortKey === "type"; onTriggered: root.fileModel.sortBy("type") }
                GlassMenuItem {
                    text: "Agrupar por Data"
                    tick: root.fileModel.groupByDate
                    onTriggered: root.fileModel.groupByDate = !root.fileModel.groupByDate
                }
            }
        }
    }

    // ── Git: branch, ↑/↓ e mudanças; o clique abre o menu de branches e sincronização ──
    Rectangle {
        id: gitPill
        visible: root.inRepo && !root.tiny
        anchors { right: tools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: gitRow.width + 20
        height: 28
        radius: 14
        color: gitArea.containsMouse || gitMenu.opened ? Theme.hover : Theme.pillBg
        border.width: 1
        border.color: Theme.border
        Row {
            id: gitRow
            anchors.centerIn: parent
            spacing: 6
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                sourceSize: Qt.size(28, 28)
                source: Theme.icon("vcs-branch-symbolic", root.git && root.git.busy ? Theme.accent : Theme.textDim)
                RotationAnimation on rotation { running: !!root.git && root.git.busy; loops: Animation.Infinite; from: 0; to: 360; duration: 1200 }
                onVisibleChanged: rotation = 0
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.git ? root.git.branch : ""
                color: Theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.narrow ? 70 : 140)
            }
            Text {
                visible: !!root.git && (root.git.ahead > 0 || root.git.behind > 0)
                anchors.verticalCenter: parent.verticalCenter
                text: root.git ? (root.git.ahead > 0 ? "↑" + root.git.ahead : "") + (root.git.behind > 0 ? (root.git.ahead > 0 ? " " : "") + "↓" + root.git.behind : "") : ""
                color: Theme.accent
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: !!root.git && root.git.changes > 0
                anchors.verticalCenter: parent.verticalCenter
                width: changesText.implicitWidth + 10; height: 16; radius: 8
                color: Theme.tint(Qt.color("#ff9f0a"), 0.22)
                Text { id: changesText; anchors.centerIn: parent; text: root.git ? root.git.changes : ""; color: "#ff9f0a"; font.pixelSize: 10; font.weight: Font.Bold }
            }
        }
        MouseArea {
            id: gitArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            ToolTip.visible: containsMouse && !gitMenu.opened
            ToolTip.delay: 600
            ToolTip.text: !root.git ? "" : root.git.busy ? root.git.busyLabel + "…"
                : "Branch " + root.git.branch + (root.git.upstream ? " → " + root.git.upstream : " (sem upstream)")
                  + (root.git.changes ? " · " + root.git.changes + (root.git.changes === 1 ? " arquivo mudou" : " arquivos mudaram") : "")
            onClicked: gitMenu.popup(gitPill, 0, gitPill.height + 4)
        }
        GlassMenu {
            id: gitMenu
            GlassMenuItem { text: "Branches"; enabled: false }
            Repeater {
                model: root.git ? root.git.branches : []
                delegate: GlassMenuItem {
                    required property string modelData
                    text: modelData
                    tick: !!root.git && modelData === root.git.branch
                    enabled: !!root.git && !root.git.busy
                    onTriggered: if (modelData !== root.git.branch) root.git.switchBranch(modelData)
                }
            }
            GlassMenuItem { text: "Nova Branch…"; enabled: !!root.git && !root.git.busy; onTriggered: root.newBranch() }
            MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
            GlassMenuItem {
                text: "Atualizar (Pull)" + (root.git && root.git.behind > 0 ? " — " + root.git.behind + " novo(s)" : "")
                enabled: !!root.git && !root.git.busy && root.git.upstream !== ""
                onTriggered: root.git.pull()
            }
            GlassMenuItem {
                text: "Enviar (Push)" + (root.git && root.git.ahead > 0 ? " — " + root.git.ahead + " commit(s)" : "")
                enabled: !!root.git && !root.git.busy
                onTriggered: root.git.push()
            }
            GlassMenuItem { text: "Buscar (Fetch)"; enabled: !!root.git && !root.git.busy; onTriggered: root.git.fetch() }
            MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
            GlassMenuItem { text: "Abrir Terminal na Raiz do Repositório"; onTriggered: root.ops.openTerminal(root.git.root) }
            GlassMenuItem { text: "Ir para a Raiz do Repositório"; onTriggered: root.navigator.go(root.git.root) }
        }
    }

    Row {
        id: tools
        anchors { right: ctlRight.visible ? ctlRight.left : parent.right; rightMargin: ctlRight.visible ? 8 : 14; verticalCenter: parent.verticalCenter }
        spacing: 6

        Row { // progresso + cancelar
            opacity: root.ops.busy ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ops.busyLabel + "…"
                color: Theme.textDim
                font.pixelSize: 11
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 90; height: 4; radius: 2
                color: Theme.pillBg
                Rectangle {
                    width: parent.width * root.ops.progress; height: parent.height; radius: 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            ToolButton { icon: "process-stop-symbolic"; width: 24; height: 24; onActivated: root.ops.cancel() }
        }

        Rectangle { // botão "Esvaziar" na Lixeira
            visible: root.fileModel.isTrash
            anchors.verticalCenter: parent.verticalCenter
            width: emptyText.implicitWidth + 24; height: 28; radius: 14
            color: emptyArea.containsMouse ? Theme.hover : Theme.pillBg
            border.width: 1
            border.color: Theme.border
            Text { id: emptyText; anchors.centerIn: parent; text: "Esvaziar"; color: Theme.text; font.pixelSize: 12 }
            MouseArea { id: emptyArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.emptyTrash() }
        }

        // botões escolhidos em Configurações → Janela e barra lateral (clique direito no topo também personaliza)
        Repeater {
            model: root.narrow ? [] : Settings.toolbar
            delegate: Loader {
                required property string modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                sourceComponent: modelData === "view" ? viewToggle
                               : modelData === "sort" ? sortButton
                               : actionButton
            }
        }

        ToolButton { // overflow no modo estreito
            visible: root.narrow
            icon: "view-more-symbolic,open-menu-symbolic,view-list-symbolic"
            onActivated: moreMenu.popup()
            GlassMenu {
                id: moreMenu
                GlassMenuItem { text: "Ícones"; tick: root.fileModel.viewMode === "grid"; onTriggered: root.fileModel.viewMode = "grid" }
                GlassMenuItem { text: "Lista"; tick: root.fileModel.viewMode === "list"; onTriggered: root.fileModel.viewMode = "list" }
                MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
                GlassMenuItem { text: "Ordenar por Nome"; tick: root.fileModel.sortKey === "name"; onTriggered: root.fileModel.sortBy("name") }
                GlassMenuItem { text: "Ordenar por Data"; tick: root.fileModel.sortKey === "modified"; onTriggered: root.fileModel.sortBy("modified") }
                GlassMenuItem { text: "Ordenar por Tamanho"; tick: root.fileModel.sortKey === "size"; onTriggered: root.fileModel.sortBy("size") }
                GlassMenuItem {
                    text: "Mostrar Arquivos Ocultos"
                    tick: root.fileModel.showHidden
                    onTriggered: root.fileModel.showHidden = !root.fileModel.showHidden
                }
                GlassMenuItem { text: "Nova Pasta"; visible: !root.fileModel.isTrash; onTriggered: root.newFolder() }
                GlassMenuItem { text: "Painel de Prévia"; shortcut: Theme.keyFor("preview", "F3"); tick: Settings.previewPanel; onTriggered: Settings.previewPanel = !Settings.previewPanel }
            }
        }

        SearchField {
            id: searchField
            compact: root.tiny
            anchors.verticalCenter: parent.verticalCenter
            fileModel: root.fileModel
            onEscaped: root.focusView()
        }
    }

    WindowControls {
        id: ctlRight
        visible: root.controlsRight
        window: root.window
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
    }
}
