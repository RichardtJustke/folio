import QtQuick
import QtQuick.Controls
import Folio

// Escolha em lista com filtro (fontes, temas de ícones…). O primeiro item é "Padrão do sistema" (valor "").
GlassPopup {
    id: root

    property string title
    property var items: []       // strings
    property string current
    property string defaultLabel: "Padrão do sistema"
    property string query: ""
    signal picked(string value)

    readonly property var filtered: {
        const q = query.trim().toLowerCase()
        return q === "" ? items : items.filter(i => i.toLowerCase().includes(q))
    }

    function show(title, items, current) {
        root.title = title
        root.items = items
        root.current = current
        root.query = ""
        filter.text = ""
        open()
        filter.forceActiveFocus()
    }

    contentItem: Column {
        spacing: 10

        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        TextField {
            id: filter
            width: parent.width
            placeholderText: "Filtrar"
            placeholderTextColor: Theme.textFaint
            color: Theme.text
            font.pixelSize: Theme.fontSize
            selectionColor: Theme.accent
            leftPadding: 12
            background: Rectangle { radius: 8; color: Theme.pillBg; border.width: 1; border.color: filter.activeFocus ? Theme.accent : Theme.border }
            onTextChanged: root.query = text
        }

        ListView {
            width: parent.width
            height: 300
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ["" ].concat(root.filtered)
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property string modelData
                width: ListView.view.width
                height: 30; radius: 8
                color: area.containsMouse ? Theme.hover : "transparent"
                Text {
                    anchors { left: parent.left; leftMargin: 10; right: tick.left; verticalCenter: parent.verticalCenter }
                    text: parent.modelData === "" ? root.defaultLabel : parent.modelData
                    color: parent.modelData === "" ? Theme.textDim : Theme.text
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
                Text {
                    id: tick
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: parent.modelData === root.current ? "✓" : ""
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.picked(parent.modelData); root.close() }
                }
            }
        }

        Row {
            anchors.right: parent.right
            DialogButton { text: "Fechar"; onClicked: root.close() }
        }
    }
}
