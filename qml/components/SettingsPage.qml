import QtQuick
import QtQuick.Controls
import Folio

// Configurações: aplicadas na hora, gravadas em ~/.config/folio/config.json.
Rectangle {
    id: root

    required property FileOps ops
    property int appsRevision: 0

    signal closed

    property string fontAtLaunch: Settings.fontFamily
    readonly property var fileKinds: [
        { label: "Pastas", mime: "inode/directory" },
        { label: "Texto", mime: "text/plain" },
        { label: "Imagens", mime: "image/png" },
        { label: "Vídeos", mime: "video/mp4" },
        { label: "Áudio", mime: "audio/mpeg" },
        { label: "PDF", mime: "application/pdf" },
        { label: "Páginas web", mime: "text/html" },
        { label: "Arquivos compactados", mime: "application/zip" }
    ]

    color: Theme.menuBg // vidro: segue a transparência da janela (o conteúdo por trás é ocultado)
    radius: Theme.radius - 4

    MouseArea { anchors.fill: parent; onWheel: w => w.accepted = true } // bloqueia o que está atrás

    readonly property var swatches: ["#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ff9f0a", "#30d158", "#64d2ff", "#98989d"]

    // ── abas ──
    readonly property var pages: [
        { id: "appearance", label: "Aparência", icon: "preferences-desktop-appearance-symbolic", sub: "Tema, cores, ícones e fonte" },
        { id: "window", label: "Janela e barra lateral", icon: "view-sidebar-symbolic", sub: "Controles da janela e barra lateral" },
        { id: "motion", label: "Animações", icon: "preferences-desktop-animation-symbolic", sub: "Movimento e velocidade" },
        { id: "behavior", label: "Comportamento", icon: "input-mouse-symbolic", sub: "Cliques, janelas, exclusão e terminal" },
        { id: "input", label: "Gestos e atalhos", icon: "input-keyboard-symbolic", sub: "Touchpad e teclado" },
        { id: "apps", label: "Aplicativos padrão", icon: "view-app-grid-symbolic", sub: "Que aplicativo abre cada tipo de arquivo" },
        { id: "about", label: "Sobre", icon: "help-about-symbolic", sub: "Versão e arquivo de configuração" }
    ]
    property string page: "appearance"

    // botões possíveis da barra de ferramentas (ids de HeaderBar.qml)
    readonly property var toolCatalog: [
        { id: "view", label: "Ícones / Lista", icon: "view-grid-symbolic" },
        { id: "sort", label: "Ordenar", icon: "view-sort-ascending-symbolic" },
        { id: "hidden", label: "Arquivos ocultos", icon: "view-conceal-symbolic" },
        { id: "newFolder", label: "Nova pasta", icon: "folder-new-symbolic" },
        { id: "preview", label: "Painel de prévia", icon: "view-dual-symbolic,view-sidebar-symbolic" },
        { id: "split", label: "Dividir janela", icon: "view-split-symbolic" },
        { id: "newTab", label: "Nova aba", icon: "tab-new-symbolic" },
        { id: "up", label: "Pasta acima", icon: "go-up-symbolic" },
        { id: "reload", label: "Recarregar", icon: "view-refresh-symbolic" },
        { id: "home", label: "Início", icon: "user-home-symbolic" },
        { id: "terminal", label: "Terminal", icon: "utilities-terminal-symbolic" },
        { id: "palette", label: "Paleta de comandos", icon: "system-run-symbolic" },
        { id: "quickOpen", label: "Busca rápida", icon: "system-search-symbolic" },
        { id: "copyPath", label: "Copiar caminho", icon: "edit-copy-symbolic" }
    ]
    function toolInfo(id) { return toolCatalog.find(t => t.id === id) || { id: id, label: id, icon: "" } }
    function moveTool(i, delta) {
        const t = Settings.toolbar.slice()
        const j = i + delta
        if (j < 0 || j >= t.length) return
        const x = t[i]; t[i] = t[j]; t[j] = x
        Settings.toolbar = t
    }

    // ── atalhos (aba Gestos e atalhos) ──
    property var actions: []
    property var keysFor: a => a.keys
    property string recording: ""   // id da ação esperando a tecla nova
    property var notices: ({})      // id → aviso ("Tirado de “Copiar”")
    readonly property var keyRows: {
        const out = []
        let last = ""
        for (const a of actions) {
            if (a.group !== last) { out.push({ header: true, group: a.group }); last = a.group }
            out.push({ header: false, action: a })
        }
        return out
    }
    function startRecording(id) {
        recording = id
        keyRecorder.forceActiveFocus()
    }
    function assignKey(id, name) {
        const n = Object.assign({}, notices)
        delete n[id]
        if (name !== "") {
            // a combinação sai de quem já a usava
            for (const a of actions) {
                if (a.id === id) continue
                const ks = keysFor(a)
                if (!ks.includes(name)) continue
                Settings.setShortcut(a.id, ks.filter(k => k !== name))
                n[id] = "Tirado de “" + a.label + "”"
            }
        }
        const a = actions.find(x => x.id === id)
        const next = name === "" ? [] : [name]
        if (a && JSON.stringify(a.keys) === JSON.stringify(next)) Settings.resetShortcut(id)
        else Settings.setShortcut(id, next)
        notices = n
        recording = ""
    }

    Item { // recebe a combinação durante a gravação (antes dos atalhos da janela)
        id: keyRecorder
        Keys.onShortcutOverride: e => e.accepted = root.recording !== ""
        Keys.onPressed: e => {
            if (root.recording === "") return
            e.accepted = true
            if (e.key === Qt.Key_Escape && !e.modifiers) { root.recording = ""; return }
            if ((e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete) && !e.modifiers) { root.assignKey(root.recording, ""); return }
            const name = Settings.keyName(e.key, e.modifiers)
            if (name) root.assignKey(root.recording, name)
        }
        onActiveFocusChanged: if (!activeFocus) root.recording = ""
    }
    property string query: ""
    readonly property string needle: query.trim().toLowerCase()
    function pageInfo(id) { return pages.find(p => p.id === id) }
    function matches(text) { return text.toLowerCase().includes(needle) }
    // na busca: quantas opções de cada aba batem
    readonly property var hits: {
        const out = {}
        if (!needle) return out
        for (const c of col.children)
            if (c.page && c.searchText !== undefined && matches(c.searchText)) out[c.page] = (out[c.page] || 0) + 1
        return out
    }
    readonly property int hitCount: Object.values(hits).reduce((a, b) => a + b, 0)
    function openPage(id) { query = ""; page = id; flick.contentY = 0 }

    component SectionTitle: Text {
        property string page
        visible: root.needle !== "" && (root.hits[page] || 0) > 0
        text: root.pageInfo(page).label
        width: parent.width
        topPadding: 18
        color: Theme.textFaint
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component PageItem: Item { // bloco sem rótulo: só aparece na própria aba, fora da busca
        property string page
        width: parent.width
        visible: root.needle === "" && root.page === page
    }

    component Line: Item {
        id: line
        property string page
        property string label
        property string hint
        property string keywords // termos extras para a busca
        readonly property string searchText: label + " " + hint + " " + keywords
        visible: root.needle !== "" ? root.matches(searchText) : root.page === page
        default property alias content: slot.data
        // em janelas estreitas o controle vai para baixo do rótulo
        readonly property bool stacked: width < 440
        width: parent.width
        height: stacked ? lbl.height + slot.height + 26 : Math.max(40, lbl.height + 16, slot.height + 12)
        Column {
            id: lbl
            x: 0
            y: line.stacked ? 8 : (line.height - height) / 2
            width: line.stacked ? line.width : Math.max(80, line.width - slot.width - 12)
            spacing: 2
            Text { width: parent.width; text: line.label; color: Theme.text; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
            Text { visible: line.hint !== ""; width: parent.width; text: line.hint; color: Theme.textDim; font.pixelSize: 11; wrapMode: Text.Wrap }
        }
        Item {
            id: slot
            x: line.stacked ? 0 : line.width - width
            y: line.stacked ? lbl.height + 14 : (line.height - height) / 2
            width: childrenRect.width; height: childrenRect.height
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }

    component Segmented: Rectangle {
        id: seg
        property var options: [] // [{value, label}]
        property string current
        signal picked(string value)
        width: row.width + 4; height: 28; radius: 14
        color: Theme.pillBg
        border.width: 1; border.color: Theme.border
        Row {
            id: row
            x: 2; y: 2
            Repeater {
                model: seg.options
                delegate: Rectangle {
                    required property var modelData
                    width: t.implicitWidth + 20; height: 24; radius: 12
                    color: seg.current === modelData.value ? Theme.accent : "transparent"
                    Text {
                        id: t
                        anchors.centerIn: parent
                        text: modelData.label
                        color: seg.current === modelData.value ? "white" : Theme.text
                        font.pixelSize: 12
                    }
                    MouseArea { anchors.fill: parent; onClicked: seg.picked(modelData.value) }
                }
            }
        }
    }

    component Toggle: Rectangle {
        id: tg
        property bool on
        signal toggled(bool value)
        width: 40; height: 24; radius: 12
        color: on ? Theme.accent : Theme.buttonBg
        Rectangle {
            width: 18; height: 18; radius: 9
            y: 3; x: tg.on ? 19 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.dur(110); easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled(!tg.on) }
    }

    component Stepper: Slider {
        id: sl
        implicitWidth: 170
        implicitHeight: 24
        background: Rectangle {
            x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - 2
            width: sl.availableWidth; height: 4; radius: 2
            color: Theme.buttonBg
            Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
        }
        handle: Rectangle {
            x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: 16; height: 16; radius: 8
            color: "white"
            border.width: 1; border.color: Theme.borderStrong
        }
    }

    ListPickerDialog {
        id: picker
        onPicked: v => Settings.fontFamily = v
    }
    ListPickerDialog {
        id: iconPicker
        defaultLabel: "Padrão do sistema"
        onPicked: v => Settings.iconTheme = v
    }

    readonly property bool narrow: width < 640
    // ao abrir, já dá para digitar e buscar
    onVisibleChanged: {
        if (visible) searchField.forceActiveFocus()
        else recording = ""
    }

    // cabeçalho
    Item {
        id: top
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54
        Text {
            id: heading
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            text: "Configurações"
            color: Theme.text
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Rectangle {
            id: closeBtn
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            width: 28; height: 28; radius: 14
            color: closeArea.containsMouse ? Theme.hover : "transparent"
            Image {
                anchors.centerIn: parent
                width: 12; height: 12
                sourceSize: Qt.size(24, 24)
                source: Theme.icon("window-close-symbolic", Theme.textDim)
            }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closed() }
        }
    }

    // busca: no topo da lista de abas (em janela estreita, no cabeçalho)
    Rectangle {
        id: searchBox
        x: root.narrow ? heading.x + heading.width + 16 : 16
        y: root.narrow ? (top.height - height) / 2 : top.height
        width: root.narrow ? Math.max(120, closeBtn.x - x - 12) : nav.width - 8
        height: 32
        radius: 9
        color: Theme.pillBg
        border.width: 1
        border.color: searchField.activeFocus ? Theme.accent : Theme.border
        Image {
            id: searchIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13
            sourceSize: Qt.size(26, 26)
            source: Theme.icon("system-search-symbolic", Theme.textFaint)
        }
        TextField {
            id: searchField
            anchors { left: searchIcon.right; leftMargin: 4; right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            text: root.query
            onTextEdited: { root.query = text; flick.contentY = 0 }
            placeholderText: "Buscar configuração"
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: 12
            selectionColor: Theme.accent
            background: null
            Keys.onEscapePressed: e => { if (root.query) { root.query = ""; e.accepted = true } else e.accepted = false }
        }
    }

    Column {
        id: nav
        anchors { left: parent.left; leftMargin: 12; top: root.narrow ? top.bottom : searchBox.bottom; topMargin: 10 }
        width: root.narrow ? 44 : 212
        spacing: 2
        Repeater {
            model: root.pages
            delegate: Rectangle {
                id: navItem
                required property var modelData
                readonly property bool current: root.needle === "" && root.page === modelData.id
                readonly property int count: root.hits[modelData.id] || 0
                width: nav.width
                height: 34
                radius: 9
                opacity: root.needle !== "" && count === 0 ? 0.45 : 1
                color: current ? Theme.selected : navArea.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur(90) } }
                Image {
                    x: root.narrow ? (parent.width - width) / 2 : 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: Theme.icon(navItem.modelData.icon, navItem.current ? Theme.accent : Theme.textDim)
                }
                Text {
                    visible: !root.narrow
                    anchors { left: parent.left; leftMargin: 38; right: badge.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: navItem.modelData.label
                    color: navItem.current ? Theme.text : Theme.textDim
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
                Rectangle { // na busca: quantas opções desta aba batem
                    id: badge
                    visible: !root.narrow && navItem.count > 0
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: visible ? Math.max(18, badgeText.implicitWidth + 10) : 0; height: 18; radius: 9
                    color: Theme.tint(Theme.accent, 0.22)
                    Text { id: badgeText; anchors.centerIn: parent; text: navItem.count; color: Theme.accent; font.pixelSize: 10; font.weight: Font.Bold }
                }
                MouseArea {
                    id: navArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    ToolTip.visible: root.narrow && containsMouse
                    ToolTip.text: navItem.modelData.label
                    ToolTip.delay: 400
                    onClicked: root.openPage(navItem.modelData.id)
                }
            }
        }
    }

    Rectangle { // painel da aba
        id: panel
        anchors { left: nav.right; leftMargin: 12; right: parent.right; rightMargin: 12; top: top.bottom; bottom: parent.bottom; bottomMargin: 12 }
        radius: Theme.radius - 6
        color: Theme.subtle
        border.width: 1
        border.color: Theme.border
    }

    Flickable {
        id: flick
        anchors.fill: panel
        anchors.margins: 1
        contentWidth: width
        contentHeight: col.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            x: Math.max(20, Math.min(36, (parent.width - width) / 2))
            width: Math.min(620, parent.width - 40)

            Item { // título da aba
                width: parent.width
                height: 72
                visible: root.needle === ""
                Image {
                    id: pageIcon
                    y: 24
                    width: 18; height: 18
                    sourceSize: Qt.size(36, 36)
                    source: Theme.icon(root.pageInfo(root.page).icon, Theme.accent)
                }
                Text {
                    anchors { left: pageIcon.right; leftMargin: 10; verticalCenter: pageIcon.verticalCenter }
                    text: root.pageInfo(root.page).label
                    color: Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                Text {
                    y: 48
                    text: root.pageInfo(root.page).sub
                    color: Theme.textFaint
                    font.pixelSize: 11
                }
            }
            Text {
                visible: root.needle !== "" && root.hitCount === 0
                width: parent.width
                topPadding: 28
                text: "Nada encontrado para “" + root.query.trim() + "”"
                color: Theme.textDim
                font.pixelSize: Theme.fontSize
                wrapMode: Text.Wrap
            }

            // ── Aparência ──
            SectionTitle { page: "appearance" }
            Line {
                page: "appearance"
                label: "Tema"
                keywords: "escuro claro automático sistema modo noturno"
                Row {
                    spacing: 8
                    Repeater {
                        model: [{ value: "dark", label: "Escuro" }, { value: "light", label: "Claro" }, { value: "auto", label: "Automático" }]
                        delegate: Rectangle {
                            id: themeCard
                            required property var modelData
                            readonly property bool on: Settings.theme === modelData.value
                            width: 92; height: 76; radius: 10
                            color: Theme.pillBg
                            border.width: on ? 2 : 1
                            border.color: on ? Theme.accent : Theme.border
                            component Mini: Rectangle {
                                property bool lightLook
                                radius: 5
                                color: lightLook ? "#f2f2f4" : "#1c1c1e"
                                Rectangle { x: 4; y: 4; width: parent.width * 0.3; height: parent.height - 8; radius: 3; color: parent.lightLook ? "#dedee3" : "#2e2e31" }
                                Rectangle { x: parent.width * 0.3 + 8; y: 6; width: parent.width * 0.45; height: 4; radius: 2; color: parent.lightLook ? "#c4c4ca" : "#48484c" }
                                Rectangle { x: parent.width * 0.3 + 8; y: 14; width: parent.width * 0.3; height: 4; radius: 2; color: Theme.accent }
                            }
                            Item {
                                x: 6; y: 6; width: parent.width - 12; height: 44
                                clip: true
                                Mini { anchors.fill: parent; lightLook: themeCard.modelData.value === "light" }
                                Item { // automático: metade direita clara
                                    visible: themeCard.modelData.value === "auto"
                                    x: parent.width / 2; width: parent.width / 2; height: parent.height
                                    clip: true
                                    Mini { x: -parent.x; width: parent.parent.width; height: parent.height; lightLook: true }
                                }
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                                text: themeCard.modelData.label
                                color: themeCard.on ? Theme.text : Theme.textDim
                                font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.theme = themeCard.modelData.value }
                        }
                    }
                }
            }
            Line {
                page: "appearance"
                label: "Cor de destaque"
                Row {
                    spacing: 8
                    Repeater {
                        model: root.swatches
                        delegate: Rectangle {
                            required property string modelData
                            width: 22; height: 22; radius: 11
                            color: modelData
                            border.width: Settings.accent.toLowerCase() === modelData ? 2 : 0
                            border.color: Theme.text
                            MouseArea { anchors.fill: parent; onClicked: Settings.accent = parent.modelData }
                        }
                    }
                }
            }
            Line {
                page: "appearance"
                label: "Cor personalizada"
                hint: "Hex, ex.: #ff7a59"
                TextField {
                    width: 110
                    text: Settings.accent
                    color: Theme.text
                    font.pixelSize: 12
                    selectionColor: Theme.accent
                    background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: parent.activeFocus ? Theme.accent : Theme.border }
                    onEditingFinished: Settings.accent = text
                }
            }
            Line {
                page: "appearance"
                label: "Transparência da janela"
                hint: "Menor = mais vidro (precisa de blur no compositor)"
                Stepper { from: 0.3; to: 1.0; value: Settings.backgroundOpacity; onMoved: Settings.backgroundOpacity = value }
            }
            Line {
                page: "appearance"
                label: "Arredondamento"
                Stepper { from: 0; to: 28; stepSize: 1; value: Settings.cornerRadius; onMoved: Settings.cornerRadius = Math.round(value) }
            }
            Line {
                page: "appearance"
                label: "Tamanho dos ícones"
                hint: "Também: Ctrl + / Ctrl -"
                Stepper { from: 40; to: 140; stepSize: 4; value: Settings.iconSize; onMoved: Settings.iconSize = Math.round(value) }
            }
            Line {
                page: "appearance"
                label: "Tamanho da fonte"
                Stepper { from: 10; to: 18; stepSize: 1; value: Settings.fontSize; onMoved: Settings.fontSize = Math.round(value) }
            }
            Line {
                page: "appearance"
                label: "Fonte"
                hint: Settings.fontFamily !== root.fontAtLaunch ? "Reinicie o Folio para aplicar em toda a interface" : "Família usada em toda a interface"
                Row {
                    spacing: 8
                    DialogButton {
                        visible: Settings.fontFamily !== root.fontAtLaunch
                        text: "Reiniciar"
                        primary: true
                        onClicked: Settings.restart()
                    }
                    DialogButton {
                        text: Settings.fontFamily || "Padrão do sistema"
                        onClicked: picker.show("Escolher fonte", Settings.availableFonts(), Settings.fontFamily)
                    }
                }
            }
            Line {
                page: "appearance"
                label: "Ícones dos arquivos"
                hint: "Estilo dos ícones na área de arquivos"
                Segmented {
                    options: [{ value: "duotone", label: "Duotone" }, { value: "mac", label: "macOS" },
                              { value: "outline", label: "Contorno" }, { value: "flat", label: "Plano" },
                              { value: "system", label: "Sistema" }]
                    current: Settings.fileIcons
                    onPicked: v => Settings.fileIcons = v
                }
            }
            Line {
                page: "appearance"
                label: "Tema de ícones"
                hint: "Aplicado na hora"
                DialogButton {
                    text: Settings.iconTheme || Settings.currentIconTheme()
                    onClicked: iconPicker.show("Escolher tema de ícones", Settings.availableIconThemes(), Settings.iconTheme)
                }
            }
            Line {
                page: "appearance"
                label: "Melhorar legibilidade"
                hint: "Com transparência: reforça o contraste dos textos e escurece/clareia o fundo da área de arquivos"
                Toggle { on: Settings.legibility; onToggled: v => Settings.legibility = v }
            }

            Line {
                page: "appearance"
                label: "Restaurar aparência padrão"
                DialogButton { text: "Restaurar"; onClicked: Settings.resetAppearance() }
            }

            SectionTitle { page: "motion" }
            Line {
                page: "motion"
                label: "Reduzir movimento"
                hint: "Desliga todas as animações (itens voando, deslizes, transições)"
                Toggle { on: Settings.reduceMotion; onToggled: v => Settings.reduceMotion = v }
            }
            Line {
                page: "motion"
                label: "Velocidade das animações"
                hint: Settings.animationSpeed.toFixed(1) + "× — maior = mais rápido"
                Stepper {
                    from: 0.5; to: 2; stepSize: 0.1
                    value: Settings.animationSpeed
                    enabled: !Settings.reduceMotion
                    onMoved: Settings.animationSpeed = Math.round(value * 10) / 10
                }
            }

            SectionTitle { page: "window" }
            Line {
                page: "window"
                label: "Controles da janela"
                hint: "Minimizar, maximizar e fechar"
                Segmented {
                    options: [{ value: "right", label: "Direita" }, { value: "left", label: "Esquerda" }, { value: "hidden", label: "Ocultos" }]
                    current: Settings.windowControls
                    onPicked: v => Settings.windowControls = v
                }
            }
            Line {
                page: "window"
                label: "Barra lateral"
                hint: Settings.sidebarMode === "autohide" ? "Some sozinha: encoste o cursor na borda esquerda (ou arraste um arquivo até ela) para mostrar; Ctrl+B também"
                    : "Pela largura: cheia, só ícones ou oculta conforme o tamanho da janela (Ctrl+B alterna)"
                keywords: "automática esconder some sozinha borda auto ocultar"
                Segmented {
                    options: [{ value: "auto", label: "Pela largura" }, { value: "autohide", label: "Some sozinha" },
                              { value: "full", label: "Cheia" }, { value: "compact", label: "Ícones" }, { value: "hidden", label: "Oculta" }]
                    current: Settings.sidebarMode
                    onPicked: v => Settings.sidebarMode = v
                }
            }

            Line {
                page: "window"
                label: "Barra de ferramentas"
                hint: "Botões do topo, da esquerda para a direita. Clique direito no topo também abre aqui"
                keywords: "botões personalizar toolbar topo ícones"
                DialogButton { text: "Restaurar"; onClicked: Settings.resetToolbar() }
            }
            PageItem {
                page: "window"
                visible: root.needle === "" ? root.page === "window" : root.matches("barra de ferramentas botões personalizar toolbar topo ícones")
                height: toolFlow.height + 20
                Flow {
                    id: toolFlow
                    y: 8
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: Settings.toolbar
                        delegate: Rectangle {
                            id: toolChip
                            required property string modelData
                            required property int index
                            readonly property var info: root.toolInfo(modelData)
                            width: chipRow.width + 12; height: 32; radius: 9
                            color: Theme.pillBg
                            border.width: 1; border.color: Theme.border
                            component ChipBtn: Rectangle {
                                id: mini
                                property string glyph
                                property bool active: true
                                signal hit
                                width: 20; height: 20; radius: 10
                                opacity: active ? 1 : 0.3
                                color: miniArea.containsMouse && active ? Theme.hover : "transparent"
                                Text { anchors.centerIn: parent; text: mini.glyph; color: Theme.textDim; font.pixelSize: 13 }
                                MouseArea { id: miniArea; anchors.fill: parent; hoverEnabled: true; enabled: mini.active; onClicked: mini.hit() }
                            }
                            Row {
                                id: chipRow
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                ChipBtn { glyph: "‹"; active: toolChip.index > 0; onHit: root.moveTool(toolChip.index, -1) }
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14; height: 14
                                    sourceSize: Qt.size(28, 28)
                                    source: Theme.icon(toolChip.info.icon, Theme.text)
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: toolChip.info.label; color: Theme.text; font.pixelSize: 12 }
                                ChipBtn { glyph: "›"; active: toolChip.index < Settings.toolbar.length - 1; onHit: root.moveTool(toolChip.index, 1) }
                                ChipBtn { glyph: "×"; onHit: Settings.toolbar = Settings.toolbar.filter(t => t !== toolChip.modelData) }
                            }
                        }
                    }
                    Rectangle { // adicionar um botão que não está na barra
                        readonly property var missing: root.toolCatalog.filter(t => !Settings.toolbar.includes(t.id))
                        visible: missing.length > 0
                        width: addText.implicitWidth + 24; height: 32; radius: 9
                        color: addArea.containsMouse ? Theme.hover : "transparent"
                        border.width: 1; border.color: Theme.border
                        Text { id: addText; anchors.centerIn: parent; text: "+ Adicionar"; color: Theme.accent; font.pixelSize: 12 }
                        MouseArea { id: addArea; anchors.fill: parent; hoverEnabled: true; onClicked: addToolMenu.popup() }
                        GlassMenu {
                            id: addToolMenu
                            Repeater {
                                model: parent ? parent.parent.missing : []
                                delegate: GlassMenuItem {
                                    required property var modelData
                                    text: modelData.label
                                    onTriggered: Settings.toolbar = Settings.toolbar.concat([modelData.id])
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { page: "behavior" }
            Line {
                page: "behavior"
                label: "Abrir com um clique"
                Toggle { on: Settings.singleClick; onToggled: v => Settings.singleClick = v }
            }
            Line {
                page: "behavior"
                label: "Janela única"
                hint: "Abrir o Folio de novo (Super+E, outros apps) usa a janela aberta, numa aba nova. Ctrl+N ainda abre outra janela"
                Toggle { on: Settings.singleWindow; onToggled: v => Settings.singleWindow = v }
            }
            Line {
                page: "behavior"
                label: "Confirmar antes de excluir permanentemente"
                Toggle { on: Settings.confirmTrash; onToggled: v => Settings.confirmTrash = v }
            }
            Line {
                page: "behavior"
                label: "Terminal"
                hint: "Comando usado em “Abrir Terminal Aqui” (F4). Vazio = detectar automaticamente"
                TextField {
                    width: 150
                    text: Settings.terminal
                    placeholderText: Settings.detectedTerminal() || "kitty"
                    placeholderTextColor: Theme.textFaint
                    color: Theme.text
                    font.pixelSize: 12
                    selectionColor: Theme.accent
                    background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: parent.activeFocus ? Theme.accent : Theme.border }
                    onEditingFinished: Settings.terminal = text
                }
            }

            SectionTitle { page: "input" }
            Line {
                page: "input"
                label: "Gestos do touchpad"
                keywords: "swipe deslizar dedos voltar avançar"
                hint: "Deslizar dois dedos para a direita volta; para a esquerda avança"
                Toggle { on: Settings.swipeNavigation; onToggled: v => Settings.swipeNavigation = v }
            }
            Line {
                page: "input"
                label: "Inverter direção do gesto"
                hint: "Use se voltar e avançar saírem trocados no seu touchpad"
                Toggle { on: Settings.swipeInvert; onToggled: v => Settings.swipeInvert = v }
            }

            PageItem {
                page: "input"
                height: 44
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 6 }
                    width: parent.width - restoreAll.width - 12
                    text: "Clique num atalho e aperte a combinação nova. Backspace deixa sem atalho; Esc cancela."
                    color: Theme.textDim
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
                DialogButton {
                    id: restoreAll
                    visible: Object.keys(Settings.shortcuts).length > 0
                    anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
                    text: "Restaurar todos"
                    onClicked: { Settings.resetAllShortcuts(); root.notices = ({}) }
                }
            }
            Repeater {
                model: root.keyRows
                delegate: Item {
                    id: keyRow
                    required property var modelData
                    readonly property bool header: modelData.header
                    readonly property var action: modelData.action
                    readonly property var keys: header ? [] : root.keysFor(action)
                    readonly property bool custom: !header && Settings.shortcuts[action.id] !== undefined
                    readonly property bool recordingThis: !header && root.recording === action.id
                    readonly property string notice: header ? "" : root.notices[action.id] || ""
                    readonly property string page: "input"
                    readonly property string searchText: header ? "" : action.label + " " + action.group + " " + keys.join(" ") + " atalho tecla"
                    width: parent.width
                    height: header ? 34 : 40
                    visible: header ? root.needle === "" && root.page === "input"
                                    : root.needle !== "" ? root.matches(searchText) : root.page === "input"

                    Text {
                        visible: keyRow.header
                        anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 6 }
                        text: keyRow.modelData.group || ""
                        color: Theme.textFaint
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                    }

                    Column {
                        visible: !keyRow.header
                        anchors { left: parent.left; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        Text { width: parent.width; text: keyRow.header ? "" : keyRow.action.label; color: Theme.text; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
                        Text { visible: keyRow.notice !== ""; text: keyRow.notice; color: Theme.accent; font.pixelSize: 10 }
                    }
                    Row {
                        id: chips
                        visible: !keyRow.header
                        anchors { right: resetBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: keyRow.recordingThis ? ["Pressione as teclas…"] : keyRow.keys.length ? keyRow.keys : ["Sem atalho"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool placeholder: keyRow.recordingThis || keyRow.keys.length === 0
                                width: chipText.implicitWidth + 16; height: 24; radius: 6
                                color: keyRow.recordingThis ? Theme.tint(Theme.accent, 0.16) : chipArea.containsMouse ? Theme.hover : Theme.pillBg
                                border.width: 1
                                border.color: keyRow.recordingThis ? Theme.accent : Theme.border
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: placeholder ? (keyRow.recordingThis ? Theme.accent : Theme.textFaint) : Theme.text
                                    font.pixelSize: 11
                                    font.family: placeholder ? Qt.application.font.family : "monospace"
                                }
                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keyRow.recordingThis ? root.recording = "" : root.startRecording(keyRow.action.id)
                                }
                            }
                        }
                    }
                    Rectangle { // volta ao padrão
                        id: resetBtn
                        visible: !keyRow.header
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 24; height: 24; radius: 12
                        opacity: keyRow.custom ? 1 : 0
                        color: resetArea.containsMouse ? Theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "↺"; color: Theme.textDim; font.pixelSize: 14 }
                        MouseArea {
                            id: resetArea
                            anchors.fill: parent
                            enabled: keyRow.custom
                            hoverEnabled: true
                            ToolTip.visible: containsMouse && keyRow.custom
                            ToolTip.text: "Padrão: " + (keyRow.header ? "" : keyRow.action.keys.join(", ") || "sem atalho")
                            ToolTip.delay: 400
                            onClicked: Settings.resetShortcut(keyRow.action.id)
                        }
                    }
                    Rectangle { visible: !keyRow.header; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                }
            }

            SectionTitle { page: "apps" }
            Repeater {
                model: root.fileKinds
                delegate: Line {
                    page: "apps"
                    id: kindLine
                    required property var modelData
                    label: modelData.label
                    Rectangle {
                        id: pick
                        readonly property string current: root.appsRevision >= 0 ? root.ops.defaultAppName(kindLine.modelData.mime) : ""
                        width: Math.min(220, Math.max(120, pickText.implicitWidth + 40)); height: 28; radius: 14
                        color: pickArea.containsMouse ? Theme.hover : Theme.pillBg
                        border.width: 1; border.color: Theme.border
                        Text {
                            id: pickText
                            anchors { left: parent.left; leftMargin: 12; right: arrow.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: pick.current || "Padrão do sistema"
                            color: pick.current ? Theme.text : Theme.textDim
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Image {
                            id: arrow
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 12; height: 12
                            sourceSize: Qt.size(24, 24)
                            source: Theme.icon("pan-down-symbolic,go-down-symbolic", Theme.textDim)
                        }
                        MouseArea { id: pickArea; anchors.fill: parent; hoverEnabled: true; onClicked: appMenu.popup() }

                        GlassMenu {
                            id: appMenu
                            readonly property var apps: root.ops.appsForMime(kindLine.modelData.mime)
                            GlassMenuItem {
                                visible: appMenu.apps.length === 0
                                enabled: false
                                text: "Nenhum aplicativo disponível"
                            }
                            Repeater {
                                model: appMenu.apps
                                delegate: GlassMenuItem {
                                    required property var modelData
                                    text: modelData.name
                                    onTriggered: {
                                        if (root.ops.setDefaultApp(kindLine.modelData.mime, modelData.id))
                                            root.appsRevision++
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { page: "about" }
            PageItem {
                page: "about"
                height: 120
                Image {
                    id: logo
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 72; height: 72
                    sourceSize: Qt.size(144, 144)
                    source: "qrc:/qt/qml/Folio/assets/folio.svg"
                }
                Column {
                    anchors { left: logo.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Text { text: "Folio"; color: Theme.text; font.pixelSize: 20; font.weight: Font.Bold }
                    Text { text: "Versão Alpha " + Settings.version; color: Theme.accent; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: "Gerenciador de arquivos minimalista para Linux/Wayland"; color: Theme.textDim; font.pixelSize: 12 }
                    Text { text: "Qt " + Settings.qtVersion + " · QML"; color: Theme.textFaint; font.pixelSize: 11 }
                }
            }
            Line {
                page: "about"
                label: "Arquivo de configuração"
                hint: Settings.configPath()
                Item { width: 1; height: 1 }
            }
            Text {
                visible: root.needle === "" && root.page === "about"
                width: parent.width
                topPadding: 10
                text: "Esta é uma versão alpha: recursos podem mudar e haver falhas. Use com cuidado em arquivos importantes."
                color: Theme.textFaint
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
    }
}
