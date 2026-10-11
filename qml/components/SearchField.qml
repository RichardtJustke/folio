import QtQuick
import QtQuick.Controls
import Folio

// Busca: filtra a pasta atual ao digitar; "Subpastas" busca recursivamente.
Rectangle {
    id: root

    required property FileModel fileModel
    property bool compact: false
    property bool open: false
    signal escaped

    readonly property bool active: field.activeFocus || field.text !== ""

    function focusField() {
        open = true
        field.forceActiveFocus()
        field.selectAll()
    }

    width: compact ? (active || open ? 170 : 32) : (active ? 260 : 170)
    height: 32
    radius: 16
    color: Theme.pillBg
    border.width: 1
    border.color: field.activeFocus ? Theme.accent : Theme.border
    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Image {
        id: glass
        anchors { left: parent.left; leftMargin: root.compact && !root.active ? 9 : 10; verticalCenter: parent.verticalCenter }
        width: 14; height: 14
        sourceSize: Qt.size(28, 28)
        source: Theme.icon("system-search-symbolic", Theme.textDim)
    }

    TextField {
        id: field
        anchors { left: glass.right; leftMargin: 4; right: chip.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        visible: !root.compact || root.active || root.open
        onActiveFocusChanged: if (!activeFocus && text === "") root.open = false
        placeholderText: "Buscar"
        placeholderTextColor: Theme.textFaint
        color: Theme.text
        font.pixelSize: Theme.fontSize
        selectionColor: Theme.accent
        background: null
        padding: 2
        text: root.fileModel.searchQuery
        onTextEdited: root.fileModel.searchQuery = text
        Keys.onEscapePressed: {
            root.fileModel.searchQuery = ""
            root.escaped()
        }
        Keys.onDownPressed: root.escaped() // desce para os resultados
        onAccepted: root.escaped()
    }

    Rectangle { // chip "Subpastas"
        id: chip
        visible: field.text !== ""
        anchors { right: clear.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        width: visible ? chipText.implicitWidth + 14 : 0
        height: 20
        radius: 10
        color: root.fileModel.searchRecursive ? Theme.accent : Theme.hover
        Text {
            id: chipText
            anchors.centerIn: parent
            text: "Subpastas"
            color: root.fileModel.searchRecursive ? "white" : Theme.textDim
            font.pixelSize: 11
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.fileModel.searchRecursive = !root.fileModel.searchRecursive
        }
    }

    Image {
        id: clear
        visible: field.text !== ""
        anchors { right: parent.right; rightMargin: visible ? 9 : 0; verticalCenter: parent.verticalCenter }
        width: visible ? 14 : 0; height: 14
        sourceSize: Qt.size(28, 28)
        source: Theme.icon("edit-clear-symbolic", Theme.textDim)
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: { root.fileModel.searchQuery = ""; root.escaped() }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.compact && !root.active && !root.open
        onClicked: root.focusField()
    }
}
