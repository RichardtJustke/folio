import QtQuick
import QtQuick.Controls
import Folio

// Adicionar nuvem: escolhe o serviço e um nome; o rclone abre o navegador para entrar na conta.
// Sem rclone instalado, explica como instalar.
GlassPopup {
    id: root

    required property CloudDrives cloud
    required property FileOps ops

    readonly property var providers: [
        { type: "drive", label: "Google Drive", name: "Google Drive" },
        { type: "onedrive", label: "OneDrive", name: "OneDrive" },
        { type: "dropbox", label: "Dropbox", name: "Dropbox" },
        { type: "box", label: "Box", name: "Box" },
        { type: "pcloud", label: "pCloud", name: "pCloud" }
    ]
    property int chosen: 0

    width: Math.min(440, Overlay.overlay ? Overlay.overlay.width - 40 : 440)
    closePolicy: cloud.busy ? Popup.NoAutoClose : Popup.CloseOnEscape

    function show() {
        chosen = 0
        nameField.text = providers[0].name
        cloud.recheck()
        open()
    }

    Connections {
        target: root.cloud
        function onAdded() { root.close() }
    }

    contentItem: Column {
        spacing: 12

        Row {
            spacing: 10
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                sourceSize: Qt.size(44, 44)
                source: Theme.icon("weather-overcast-symbolic", Theme.accent)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Adicionar nuvem"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }

        // ── sem rclone: como instalar ──
        Column {
            visible: !root.cloud.available
            width: parent.width
            spacing: 10
            Text {
                width: parent.width
                text: "O Folio usa o rclone para abrir Google Drive, OneDrive, Dropbox e outros como pastas. Instale com:"
                color: Theme.textDim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: Theme.pillBg
                border.width: 1
                border.color: Theme.border
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "sudo pacman -S rclone"
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: 12
                }
                DialogButton {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "Copiar"
                    onClicked: root.ops.copyText("sudo pacman -S rclone")
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                DialogButton { text: "Fechar"; onClicked: root.close() }
                DialogButton { text: "Verificar de novo"; primary: true; onClicked: root.cloud.recheck() }
            }
        }

        // ── com rclone: serviço + nome ──
        Column {
            visible: root.cloud.available
            width: parent.width
            spacing: 12
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: root.providers
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: root.chosen === index
                        width: provText.implicitWidth + 24; height: 30; radius: 15
                        color: on ? Theme.accent : provArea.containsMouse ? Theme.hover : Theme.pillBg
                        border.width: on ? 0 : 1
                        border.color: Theme.border
                        opacity: root.cloud.busy ? 0.5 : 1
                        Text { id: provText; anchors.centerIn: parent; text: modelData.label; color: parent.on ? "white" : Theme.text; font.pixelSize: 12 }
                        MouseArea {
                            id: provArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.cloud.busy
                            onClicked: {
                                // troca o nome sugerido, a não ser que a pessoa já tenha escrito outro
                                if (root.providers.some(p => p.name === nameField.text) || nameField.text === "") nameField.text = modelData.name
                                root.chosen = index
                            }
                        }
                    }
                }
            }
            TextField {
                id: nameField
                width: parent.width
                enabled: !root.cloud.busy
                placeholderText: "Nome na barra lateral"
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.pixelSize: 13
                selectionColor: Theme.accent
                background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: nameField.activeFocus ? Theme.accent : Theme.border }
                onAccepted: if (!root.cloud.busy) root.cloud.addRemote(text, root.providers[root.chosen].type)
            }
            Text {
                width: parent.width
                text: root.cloud.busy ? root.cloud.busyLabel
                    : "Ao conectar, o navegador abre para você entrar na conta e autorizar o rclone. Depois, a nuvem aparece em “Nuvem” na barra lateral."
                color: root.cloud.busy ? Theme.accent : Theme.textDim
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
            Item {
                width: parent.width
                height: 28
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    visible: !root.cloud.busy
                    text: "Outro serviço…"
                    color: Theme.accent
                    font.pixelSize: 12
                    font.underline: otherArea.containsMouse
                    MouseArea { id: otherArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cloud.openConfigInTerminal() }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    DialogButton { text: root.cloud.busy ? "Cancelar" : "Fechar"; onClicked: root.cloud.busy ? root.cloud.cancel() : root.close() }
                    DialogButton {
                        visible: !root.cloud.busy
                        text: "Conectar"
                        primary: true
                        onClicked: root.cloud.addRemote(nameField.text, root.providers[root.chosen].type)
                    }
                }
            }
        }
    }
}
