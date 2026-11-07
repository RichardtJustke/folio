import QtQuick
import QtQuick.Controls
import Folio

// Escolher uma pasta de destino (Copiar para… / Mover para…).
// Atalhos à esquerda, subpastas à direita; o campo aceita digitar um caminho (~ funciona).
GlassPopup {
    id: root

    required property FileOps ops
    property string title
    property string confirmText: "Escolher"
    property string dir: ""
    property var callback: null
    property var entries: []
    property string lastDir: "" // o próximo diálogo começa onde o último terminou

    function ask(title, confirmText, startDir, cb) {
        root.title = title
        root.confirmText = confirmText
        root.callback = cb
        go(lastDir || startDir)
        open()
        list.forceActiveFocus()
    }

    function go(path) {
        const p = ops.resolveDir(path)
        if (p === "") { pathField.error = true; return }
        pathField.error = false
        dir = p
        pathField.text = p
        entries = ops.subdirs(p, false)
        list.currentIndex = -1
    }

    function up() { if (dir !== "/") go(ops.parentDir(dir)) }

    function accept() {
        const cb = callback, d = dir
        lastDir = d
        callback = null
        close()
        if (cb) cb(d)
    }

    width: Math.min(620, Overlay.overlay ? Overlay.overlay.width - 40 : 620)

    contentItem: Column {
        spacing: 10

        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Row {
            width: parent.width
            spacing: 6
            DialogButton { text: "↑"; implicitWidth: 34; onClicked: root.up() }
            TextField {
                id: pathField
                property bool error: false
                width: parent.width - 40
                color: Theme.text
                font.pixelSize: 12
                selectionColor: Theme.accent
                leftPadding: 10
                background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: pathField.error ? Theme.danger : pathField.activeFocus ? Theme.accent : Theme.border }
                Keys.onReturnPressed: root.go(text)
                Keys.onEnterPressed: root.go(text)
            }
        }

        Row {
            width: parent.width
            height: 300
            spacing: 10

            ListView {
                id: places
                width: Math.min(170, parent.width * 0.32)
                height: parent.height
                clip: true
                model: root.opened ? root.ops.quickDirs() : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 30; radius: 8
                    color: modelData.path === root.dir ? Theme.overlay(0.12) : placeArea.containsMouse ? Theme.hover : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Image {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(32, 32)
                            source: Theme.icon(modelData.icon + ",folder-symbolic", Theme.textDim)
                        }
                        Text {
                            width: parent.width - 32
                            text: modelData.name
                            color: Theme.text
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: placeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.go(modelData.path) }
                }
            }

            Rectangle { width: 1; height: parent.height; color: Theme.border }

            ListView {
                id: list
                width: parent.width - places.width - 21
                height: parent.height
                clip: true
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                ScrollBar.vertical: ScrollBar {}
                Keys.onReturnPressed: currentIndex >= 0 ? root.go(root.entries[currentIndex].path) : root.accept()
                Keys.onEnterPressed: currentIndex >= 0 ? root.go(root.entries[currentIndex].path) : root.accept()
                Keys.onRightPressed: if (currentIndex >= 0) root.go(root.entries[currentIndex].path)
                Keys.onLeftPressed: root.up()
                Keys.onPressed: e => { if (e.key === Qt.Key_Backspace) { root.up(); e.accepted = true } }

                Text {
                    anchors.centerIn: parent
                    visible: root.entries.length === 0
                    text: "Sem subpastas"
                    color: Theme.textFaint
                    font.pixelSize: 12
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 30; radius: 8
                    color: ListView.isCurrentItem ? Theme.overlay(0.12) : dirArea.containsMouse ? Theme.hover : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Image {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(32, 32)
                            source: Theme.icon("folder-symbolic", Theme.accent)
                        }
                        Text {
                            width: parent.width - 32
                            text: modelData.name
                            color: Theme.text
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: dirArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: list.currentIndex = index
                        onDoubleClicked: root.go(modelData.path)
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 28
            DialogButton {
                anchors.left: parent.left
                text: "Nova Pasta"
                onClicked: {
                    const p = root.ops.createFolder(root.dir)
                    if (p) root.go(p)
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                DialogButton { text: "Cancelar"; onClicked: root.close() }
                DialogButton {
                    primary: true
                    text: list.currentIndex >= 0 ? root.confirmText + " em “" + root.entries[list.currentIndex].name + "”" : root.confirmText + " aqui"
                    onClicked: {
                        if (list.currentIndex >= 0) root.dir = root.entries[list.currentIndex].path
                        root.accept()
                    }
                }
            }
        }
    }
}
