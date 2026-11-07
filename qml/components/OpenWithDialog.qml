import QtQuick
import QtQuick.Controls
import Folio

// "Abrir com…" e escolha de aplicativo padrão.
// Mostra primeiro os apps que declaram o tipo; "Todos os aplicativos" traz o resto,
// e "Programa personalizado…" cria um atalho para AppImage, binário solto ou comando.
GlassPopup {
    id: root

    required property FileOps ops
    property var paths: []
    property string mime: ""
    property string mimeLabel: ""
    property bool pickOnly: false   // true: só escolhe (Configurações → Aplicativos padrão)
    property var callback: null     // pickOnly: callback(appId)
    property var recommended: []
    property var everything: []
    property bool showAll: false
    property bool custom: false
    property string query: ""

    readonly property var shown: {
        const q = query.trim().toLowerCase()
        const base = showAll || q !== "" || recommended.length === 0 ? everything : recommended
        return q === "" ? base : base.filter(a => a.name.toLowerCase().includes(q) || a.id.toLowerCase().includes(q))
    }

    function reset() {
        query = ""
        filter.text = ""
        showAll = false
        custom = false
        customName.text = ""
        customCmd.text = ""
        always.checked = false
        everything = ops.allApps()
    }

    // abrir arquivos: show(caminho) ou show([caminhos])
    function show(p) {
        paths = Array.isArray(p) ? p : [p]
        const info = ops.mimeInfo(paths[0])
        mime = info.mime || ""
        mimeLabel = info.label || ""
        pickOnly = false
        callback = null
        recommended = ops.openWithApps(paths[0])
        reset()
        open()
        filter.forceActiveFocus()
    }

    // escolher o padrão de um tipo: pick("image/png", "Imagem PNG", id => …)
    function pick(mimeName, label, cb) {
        paths = []
        mime = mimeName
        mimeLabel = label
        pickOnly = true
        callback = cb
        recommended = ops.appsForMime(mimeName)
        reset()
        open()
        filter.forceActiveFocus()
    }

    function choose(appId) {
        if (pickOnly) {
            const cb = callback
            close()
            if (cb) cb(appId)
            return
        }
        if (always.checked && mime !== "") ops.setDefaultApp(mime, appId)
        ops.openWithMany(paths, appId)
        close()
    }

    function createCustom() {
        const id = ops.addCustomApp(customName.text, customCmd.text)
        if (id !== "") choose(id)
    }

    width: Math.min(440, Overlay.overlay ? Overlay.overlay.width - 40 : 440)

    contentItem: Column {
        spacing: 10

        Text {
            width: parent.width
            text: root.pickOnly ? "Aplicativo para " + (root.mimeLabel || root.mime)
                : root.paths.length > 1 ? "Abrir " + root.paths.length + " itens com…" : "Abrir com…"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        // ── lista de apps ──
        Column {
            width: parent.width
            spacing: 10
            visible: !root.custom

            TextField {
                id: filter
                width: parent.width
                placeholderText: "Procurar aplicativo"
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.accent
                leftPadding: 12
                background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: filter.activeFocus ? Theme.accent : Theme.border }
                onTextChanged: root.query = text
                Keys.onReturnPressed: if (root.shown.length > 0) root.choose(root.shown[0].id)
                Keys.onEnterPressed: if (root.shown.length > 0) root.choose(root.shown[0].id)
            }

            Text {
                visible: root.shown.length === 0
                width: parent.width
                text: root.query !== "" ? "Nenhum aplicativo com esse nome." : "Nenhum aplicativo encontrado para este tipo de arquivo."
                color: Theme.textDim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, 300)
                visible: root.shown.length > 0
                clip: true
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 34; radius: 8
                    color: area.containsMouse ? Theme.hover : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Image {
                            width: 20; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(40, 40)
                            source: Theme.icon((modelData.icon || "") + ",application-x-executable")
                        }
                        Text { text: modelData.name; color: Theme.text; font.pixelSize: Theme.fontSize; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.choose(modelData.id)
                    }
                }
            }

            Row {
                spacing: 16
                LinkText {
                    visible: root.recommended.length > 0 && root.query === ""
                    text: root.showAll ? "Só os recomendados" : "Todos os aplicativos"
                    onClicked: root.showAll = !root.showAll
                }
                LinkText {
                    text: "Programa personalizado…"
                    onClicked: { root.custom = true; customName.forceActiveFocus() }
                }
            }

            CheckBox {
                id: always
                visible: !root.pickOnly && root.mime !== ""
                text: "Sempre abrir " + (root.mimeLabel || root.mime) + " com o escolhido"
                padding: 0
                indicator: Rectangle {
                    implicitWidth: 16; implicitHeight: 16
                    y: (always.height - height) / 2
                    radius: 4
                    color: always.checked ? Theme.accent : Theme.pillBg
                    border.width: 1
                    border.color: always.checked ? Theme.accent : Theme.borderStrong
                    Text { anchors.centerIn: parent; text: "✓"; visible: always.checked; color: "white"; font.pixelSize: 11 }
                }
                contentItem: Text {
                    leftPadding: always.indicator.width + 8
                    text: always.text
                    color: Theme.textDim
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // ── programa personalizado ──
        Column {
            width: parent.width
            spacing: 8
            visible: root.custom

            Text {
                width: parent.width
                text: "Para programas sem atalho no sistema: AppImage, binário ou comando. O Folio cria o atalho e ele passa a aparecer nas listas."
                color: Theme.textDim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            TextField {
                id: customName
                width: parent.width
                placeholderText: "Nome (ex.: Meu Editor)"
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.accent
                leftPadding: 12
                background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: customName.activeFocus ? Theme.accent : Theme.border }
                KeyNavigation.tab: customCmd
            }
            TextField {
                id: customCmd
                width: parent.width
                placeholderText: "Caminho ou comando (ex.: ~/Apps/editor.AppImage)"
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.pixelSize: Theme.fontSize
                font.family: "monospace"
                selectionColor: Theme.accent
                leftPadding: 12
                background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: customCmd.activeFocus ? Theme.accent : Theme.border }
                Keys.onReturnPressed: root.createCustom()
                Keys.onEnterPressed: root.createCustom()
            }
            Text {
                width: parent.width
                text: "O arquivo vai no fim do comando, ou onde estiver %f (um) / %F (vários)."
                color: Theme.textFaint
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton {
                text: root.custom ? "Voltar" : "Cancelar"
                onClicked: root.custom ? root.custom = false : root.close()
            }
            DialogButton {
                visible: root.custom
                primary: true
                text: root.pickOnly ? "Adicionar" : "Adicionar e abrir"
                onClicked: root.createCustom()
            }
        }
    }

    component LinkText: Text {
        signal clicked
        color: linkArea.containsMouse ? Theme.text : Theme.accent
        font.pixelSize: 12
        MouseArea { id: linkArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
