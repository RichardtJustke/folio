import QtQuick
import Folio

// cabeçalho de colunas da visão em lista; clique ordena (de novo inverte)
Item {
    id: root

    required property var view
    required property FileModel fileModel

    height: 28

    component HeaderCell: Item {
        id: col
        property string key
        property string label
        readonly property bool active: root.fileModel.sortKey === key

        height: root.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 5
            color: area.containsMouse ? Theme.hover : "transparent"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 8
            text: col.label + (col.active ? (root.fileModel.sortDescending ? "  ▾" : "  ▴") : "")
            color: col.active ? Theme.text : Theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: col.key !== ""
            onClicked: root.fileModel.sortBy(col.key)
        }
    }

    Row {
        anchors.fill: parent
        HeaderCell { width: root.view.nameWidth; key: "name"; label: "Nome" }
        HeaderCell { width: root.view.dateWidth; key: "modified"; label: "Data de Modificação" }
        HeaderCell { width: root.view.sizeWidth; key: "size"; label: "Tamanho" }
        HeaderCell {
            width: root.view.typeWidth
            key: root.view.showLocation ? "" : "type"
            label: root.view.showLocation ? "Local" : "Tipo"
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
}
