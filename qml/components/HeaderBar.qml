import QtQuick
import Folio

Item {
    id: root

    required property var window
    required property FileModel fileModel
    required property Navigator navigator
    required property FileOps ops

    property alias search: searchField

    signal newFolder
    signal emptyTrash
    signal focusView

    height: Theme.headerHeight

    // arrastar / duplo clique para maximizar
    MouseArea {
        anchors.fill: parent
        onPressed: root.window.startSystemMove()
        onDoubleClicked: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
    }

    NavPill {
        id: nav
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        canGoBack: root.navigator.canGoBack
        canGoForward: root.navigator.canGoForward
        onBack: root.navigator.back()
        onForward: root.navigator.forward()
    }

    Text {
        anchors { left: nav.right; leftMargin: 14; right: tools.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        text: root.fileModel.title
        color: Theme.text
        font.pixelSize: 15
        font.weight: Font.Bold
        elide: Text.ElideRight
    }

    component ToolButton: Rectangle {
        id: tb
        property string icon
        property bool checked
        signal activated

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 32; height: 32
        radius: 16
        color: checked ? Theme.selected : area.containsMouse ? Theme.hover : "transparent"
        border.width: checked ? 1 : 0
        border.color: Theme.border
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Theme.icon(tb.icon, Theme.text)
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: tb.activated() }
    }

    Row {
        id: tools
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 6

        Row { // progresso + cancelar
            visible: root.ops.busy
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ops.busyLabel + "…"
                color: Theme.textDim
                font.pixelSize: 11
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 90; height: 4; radius: 2
                color: Theme.pillBg
                Rectangle {
                    width: parent.width * root.ops.progress; height: parent.height; radius: 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            ToolButton { icon: "process-stop-symbolic"; width: 24; height: 24; onActivated: root.ops.cancel() }
        }

        Rectangle { // botão "Esvaziar" na Lixeira
            visible: root.fileModel.isTrash
            anchors.verticalCenter: parent.verticalCenter
            width: emptyText.implicitWidth + 24; height: 28; radius: 14
            color: emptyArea.containsMouse ? Theme.hover : Theme.pillBg
            border.width: 1
            border.color: Theme.border
            Text { id: emptyText; anchors.centerIn: parent; text: "Esvaziar"; color: Theme.text; font.pixelSize: 12 }
            MouseArea { id: emptyArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.emptyTrash() }
        }

        Rectangle { // grade | lista
            anchors.verticalCenter: parent.verticalCenter
            width: 68; height: 32; radius: 16
            color: Theme.pillBg
            border.width: 1
            border.color: Theme.border
            Row {
                anchors.centerIn: parent
                ToolButton {
                    width: 32; height: 28
                    icon: "view-grid-symbolic"
                    checked: root.fileModel.viewMode === "grid"
                    onActivated: root.fileModel.viewMode = "grid"
                }
                ToolButton {
                    width: 32; height: 28
                    icon: "view-list-symbolic"
                    checked: root.fileModel.viewMode === "list"
                    onActivated: root.fileModel.viewMode = "list"
                }
            }
        }

        ToolButton {
            icon: root.fileModel.sortDescending ? "view-sort-descending-symbolic" : "view-sort-ascending-symbolic"
            onActivated: sortMenu.popup()
            GlassMenu {
                id: sortMenu
                GlassMenuItem { text: "Nome"; tick: root.fileModel.sortKey === "name"; onTriggered: root.fileModel.sortBy("name") }
                GlassMenuItem { text: "Data de Modificação"; tick: root.fileModel.sortKey === "modified"; onTriggered: root.fileModel.sortBy("modified") }
                GlassMenuItem { text: "Tamanho"; tick: root.fileModel.sortKey === "size"; onTriggered: root.fileModel.sortBy("size") }
                GlassMenuItem { text: "Tipo"; tick: root.fileModel.sortKey === "type"; onTriggered: root.fileModel.sortBy("type") }
                GlassMenuItem {
                    text: "Agrupar por Data"
                    tick: root.fileModel.groupByDate
                    onTriggered: root.fileModel.groupByDate = !root.fileModel.groupByDate
                }
            }
        }
        ToolButton {
            icon: root.fileModel.showHidden ? "view-reveal-symbolic" : "view-conceal-symbolic"
            checked: root.fileModel.showHidden
            onActivated: root.fileModel.showHidden = !root.fileModel.showHidden
        }
        ToolButton { icon: "folder-new-symbolic"; visible: !root.fileModel.isTrash; onActivated: root.newFolder() }

        SearchField {
            id: searchField
            anchors.verticalCenter: parent.verticalCenter
            fileModel: root.fileModel
            onEscaped: root.focusView()
        }
    }
}
