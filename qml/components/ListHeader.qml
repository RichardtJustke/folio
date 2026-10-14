import QtQuick
import Folio

// cabeçalho de colunas da visão em lista, discreto e alinhado às linhas; clique ordena (de novo inverte)
Item {
    id: root

    required property var view
    required property FileModel fileModel

    height: 34

    component HeaderCell: Item {
        id: col
        property string key
        property string label
        property real inset: 8           // alinha com o texto da coluna nas linhas
        property bool alignRight: false
        readonly property bool active: root.fileModel.sortKey === key

        height: root.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 6
            color: area.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: col.alignRight ? col.width - width - 10 : col.inset
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: col.label
                color: col.active ? Theme.text : Theme.textDim
                font.pixelSize: 12
                font.weight: col.active ? Font.DemiBold : Font.Medium
            }
            Image {
                visible: col.active
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10
                sourceSize: Qt.size(20, 20)
                rotation: root.fileModel.sortDescending ? 0 : 180
                source: Theme.icon("pan-down-symbolic", Theme.text)
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: col.key !== ""
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.fileModel.sortBy(col.key)
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8 // mesma margem das linhas
        HeaderCell { width: root.view.nameWidth - 8; key: "name"; label: "Nome"; inset: 26 } // depois do ícone
        HeaderCell { width: root.view.dateWidth; key: "modified"; label: "Modificado"; inset: 0 }
        HeaderCell { width: root.view.sizeWidth; key: "size"; label: "Tamanho"; alignRight: true }
        HeaderCell {
            width: root.view.typeWidth
            inset: 14
            key: root.view.showLocation ? "" : "type"
            label: root.view.showLocation ? "Local" : "Tipo"
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8 }
        height: 1
        color: Theme.border
    }
}
