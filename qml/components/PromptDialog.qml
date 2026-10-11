import QtQuick
import QtQuick.Controls
import Folio

GlassPopup {
    id: root

    property string title
    property string placeholder
    property string confirmText: "OK"
    property var callback: null

    function ask(title, placeholder, confirmText, callback) {
        root.title = title
        root.placeholder = placeholder
        root.confirmText = confirmText
        root.callback = callback
        field.text = ""
        open()
        field.forceActiveFocus()
    }

    function accept() {
        const cb = callback
        const v = field.text
        callback = null
        close()
        if (cb && v.trim() !== "") cb(v)
    }

    contentItem: Column {
        spacing: 12
        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            wrapMode: Text.Wrap
        }
        TextField {
            id: field
            width: parent.width
            placeholderText: root.placeholder
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: Theme.fontSize
            selectionColor: Theme.accent
            leftPadding: 12
            background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.border }
            onAccepted: root.accept()
        }
        Row {
            anchors.right: parent.right
            spacing: 8
            DialogButton { text: "Cancelar"; onClicked: root.close() }
            DialogButton { text: root.confirmText; primary: true; onClicked: root.accept() }
        }
    }
}
