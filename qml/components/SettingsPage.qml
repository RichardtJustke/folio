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

    component SectionTitle: Text {
        width: parent.width
        topPadding: 18
        color: Theme.textFaint
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component Line: Item {
        id: line
        property string label
        property string hint
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

    // cabeçalho
    Item {
        id: top
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54
        Text {
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            text: "Configurações"
            color: Theme.text
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Rectangle {
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

    Flickable {
        anchors { left: parent.left; right: parent.right; top: top.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: col.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            x: Math.max(20, (parent.width - width) / 2)
            width: Math.min(560, parent.width - 40)

            SectionTitle { text: "Aparência" }
            Line {
                label: "Tema"
                Segmented {
                    options: [{ value: "dark", label: "Escuro" }, { value: "light", label: "Claro" }]
                    current: Settings.theme
                    onPicked: v => Settings.theme = v
                }
            }
            Line {
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
                label: "Transparência da janela"
                hint: "Menor = mais vidro (precisa de blur no compositor)"
                Stepper { from: 0.3; to: 1.0; value: Settings.backgroundOpacity; onMoved: Settings.backgroundOpacity = value }
            }
            Line {
                label: "Arredondamento"
                Stepper { from: 0; to: 28; stepSize: 1; value: Settings.cornerRadius; onMoved: Settings.cornerRadius = Math.round(value) }
            }
            Line {
                label: "Tamanho dos ícones"
                hint: "Também: Ctrl + / Ctrl -"
                Stepper { from: 40; to: 140; stepSize: 4; value: Settings.iconSize; onMoved: Settings.iconSize = Math.round(value) }
            }
            Line {
                label: "Tamanho da fonte"
                Stepper { from: 10; to: 18; stepSize: 1; value: Settings.fontSize; onMoved: Settings.fontSize = Math.round(value) }
            }
            Line {
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
                label: "Tema de ícones"
                hint: "Aplicado na hora"
                DialogButton {
                    text: Settings.iconTheme || Settings.currentIconTheme()
                    onClicked: iconPicker.show("Escolher tema de ícones", Settings.availableIconThemes(), Settings.iconTheme)
                }
            }
            Line {
                label: "Melhorar legibilidade"
                hint: "Com transparência: reforça o contraste dos textos e escurece/clareia o fundo da área de arquivos"
                Toggle { on: Settings.legibility; onToggled: v => Settings.legibility = v }
            }

            SectionTitle { text: "Animações" }
            Line {
                label: "Reduzir movimento"
                hint: "Desliga todas as animações (itens voando, deslizes, transições)"
                Toggle { on: Settings.reduceMotion; onToggled: v => Settings.reduceMotion = v }
            }
            Line {
                label: "Velocidade das animações"
                hint: Settings.animationSpeed.toFixed(1) + "× — maior = mais rápido"
                Stepper {
                    from: 0.5; to: 2; stepSize: 0.1
                    value: Settings.animationSpeed
                    enabled: !Settings.reduceMotion
                    onMoved: Settings.animationSpeed = Math.round(value * 10) / 10
                }
            }

            SectionTitle { text: "Janela e layout" }
            Line {
                label: "Controles da janela"
                hint: "Minimizar, maximizar e fechar"
                Segmented {
                    options: [{ value: "right", label: "Direita" }, { value: "left", label: "Esquerda" }, { value: "hidden", label: "Ocultos" }]
                    current: Settings.windowControls
                    onPicked: v => Settings.windowControls = v
                }
            }
            Line {
                label: "Barra lateral"
                hint: "Automático: some e encolhe conforme a largura (Ctrl+B alterna)"
                Segmented {
                    options: [{ value: "auto", label: "Auto" }, { value: "full", label: "Cheia" },
                              { value: "compact", label: "Ícones" }, { value: "hidden", label: "Oculta" }]
                    current: Settings.sidebarMode
                    onPicked: v => Settings.sidebarMode = v
                }
            }

            SectionTitle { text: "Comportamento" }
            Line {
                label: "Abrir com um clique"
                Toggle { on: Settings.singleClick; onToggled: v => Settings.singleClick = v }
            }
            Line {
                label: "Confirmar antes de excluir permanentemente"
                Toggle { on: Settings.confirmTrash; onToggled: v => Settings.confirmTrash = v }
            }
            Line {
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
            Line {
                label: "Restaurar aparência padrão"
                DialogButton { text: "Restaurar"; onClicked: Settings.resetAppearance() }
            }

            SectionTitle { text: "Aplicativos padrão" }
            Repeater {
                model: root.fileKinds
                delegate: Line {
                    id: kindLine
                    required property var modelData
                    label: modelData.label
                    Rectangle {
                        id: pick
                        readonly property string current: { root.appsRevision; return root.ops.defaultAppName(kindLine.modelData.mime) }
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

            SectionTitle { text: "Sobre" }
            Item {
                width: parent.width
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
                label: "Arquivo de configuração"
                hint: Settings.configPath()
                Item { width: 1; height: 1 }
            }
            Text {
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
