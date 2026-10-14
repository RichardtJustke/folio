import QtQuick
import Folio

// bolinhas das etiquetas de um item (sobrepostas, como no Finder)
Row {
    id: root
    property var tags: []
    property int size: 8
    spacing: -size / 3
    visible: tags && tags.length > 0
    Repeater {
        model: root.tags
        delegate: Rectangle {
            required property string modelData
            width: root.size; height: root.size; radius: root.size / 2
            color: Theme.tagColor(modelData)
            border.width: 1
            border.color: Theme.light ? "white" : Qt.rgba(0.1, 0.1, 0.11, 1)
        }
    }
}
