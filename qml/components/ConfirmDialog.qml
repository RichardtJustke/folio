import QtQuick
import Folio

GlassPopup {
    id: root

    property string title
    property string message
    property string confirmText: "OK"
    property var callback: null

    function ask(title, message, confirmText, callback) {
        root.title = title
        root.message = message
        root.confirmText = confirmText
        root.callback = callback
        open()
    }

    function accept() {
        const cb = callback
        callback = null
        close()
        if (cb) cb()
    }

    contentItem: Column {
        spacing: 10
        focus: true
        Keys.onReturnPressed: root.accept()
        Keys.onEnterPressed: root.accept()

        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: root.message
            color: Theme.textDim
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Item { width: 1; height: 6 }
        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton { text: "Cancelar"; onClicked: root.close() }
            DialogButton { text: root.confirmText; primary: true; destructive: true; onClicked: root.accept() }
        }
    }
}
