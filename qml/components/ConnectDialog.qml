import QtQuick
import QtQuick.Controls
import Folio

// Conectar a um servidor via SSH/SFTP (gvfs). Use chave SSH ou ssh-agent; hosts do ~/.ssh/config aparecem como atalhos.
GlassPopup {
    id: root

    required property FileOps ops
    property var hosts: []

    function show() {
        hosts = ops.sshHosts()
        field.text = ""
        open()
        field.forceActiveFocus()
    }

    function connectNow() {
        if (field.text.trim() === "" || ops.busy) return
        ops.connectServer(field.text)
    }

    contentItem: Column {
        spacing: 10

        Text {
            width: parent.width
            text: "Conectar ao servidor"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            text: "SSH/SFTP — usuario@host, host:porta ou um nome do ~/.ssh/config. A autenticação deve ser por chave (ssh-agent)."
            color: Theme.textDim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        TextField {
            id: field
            width: parent.width
            placeholderText: "usuario@servidor  ·  ex.: ubuntu@203.0.113.10/home/ubuntu"
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: Theme.fontSize
            selectionColor: Theme.accent
            leftPadding: 12
            background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.border }
            onAccepted: root.connectNow()
        }

        Flow {
            visible: root.hosts.length > 0
            width: parent.width
            spacing: 6
            Repeater {
                model: root.hosts
                delegate: Rectangle {
                    required property string modelData
                    width: chipText.implicitWidth + 18; height: 26; radius: 13
                    color: chipArea.containsMouse ? Theme.hover : Theme.pillBg
                    border.width: 1; border.color: Theme.border
                    Text { id: chipText; anchors.centerIn: parent; text: parent.modelData; color: Theme.text; font.pixelSize: 12 }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { field.text = parent.modelData; root.connectNow() }
                    }
                }
            }
        }

        Text {
            visible: root.ops.busy
            text: root.ops.busyLabel + "…"
            color: Theme.textDim
            font.pixelSize: 12
        }

        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton { text: "Cancelar"; onClicked: root.close() }
            DialogButton { text: "Conectar"; primary: true; onClicked: root.connectNow() }
        }
    }
}
