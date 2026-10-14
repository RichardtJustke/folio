import QtQuick
import QtQuick.Controls
import Folio

Item {
    id: root

    required property var window
    required property FileModel fileModel
    required property Navigator navigator
    required property FileOps ops

    property alias search: searchField
    property alias pathBar: pathBar
    property bool sidebarHidden: false
    readonly property bool narrow: width < 700
    readonly property bool tiny: width < 460
    readonly property bool controlsLeft: Settings.windowControls === "left"
    readonly property bool controlsRight: Settings.windowControls === "right"

    signal toggleSidebar
    signal openSettings
    signal openPath(string path)
    signal topClicked

    signal newFolder
    signal emptyTrash
    signal focusView

    height: Theme.headerHeight

    // arrastar / duplo clique para maximizar
    MouseArea {
        property point pressPos
        anchors.fill: parent
        onPressed: e => { pressPos = Qt.point(e.x, e.y); root.topClicked() }
        onPositionChanged: e => {
            // só vira "mover janela" depois de arrastar de verdade (permite duplo/triplo clique)
            if (pressed && Math.abs(e.x - pressPos.x) + Math.abs(e.y - pressPos.y) > 8) root.window.startSystemMove()
        }
    }

    WindowControls {
        id: ctlLeft
        visible: root.controlsLeft
        window: root.window
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
    }

    ToolButton {
        id: sidebarBtn
        visible: root.sidebarHidden
        icon: "sidebar-show-symbolic,view-sidebar-symbolic,go-next-symbolic"
        anchors.left: ctlLeft.visible ? ctlLeft.right : parent.left
        anchors.leftMargin: 10
        onActivated: root.toggleSidebar()
    }

    NavPill {
        id: nav
        anchors {
            left: sidebarBtn.visible ? sidebarBtn.right : ctlLeft.visible ? ctlLeft.right : parent.left
            leftMargin: sidebarBtn.visible || ctlLeft.visible ? 8 : 14
            verticalCenter: parent.verticalCenter
        }
        canGoBack: root.navigator.canGoBack
        canGoForward: root.navigator.canGoForward
        onBack: root.navigator.back()
        onForward: root.navigator.forward()
    }

    PathBar {
        id: pathBar
        anchors { left: nav.right; leftMargin: 12; right: tools.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        path: root.fileModel.path
        title: root.fileModel.title
        special: root.fileModel.isTrash || root.fileModel.isSearch
        ops: root.ops
        onNavigate: p => root.navigator.go(p)
        onSubmitted: typed => root.openPath(typed)
        onClosed: root.focusView()
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
        anchors { right: ctlRight.visible ? ctlRight.left : parent.right; rightMargin: ctlRight.visible ? 8 : 14; verticalCenter: parent.verticalCenter }
        spacing: 6

        Row { // progresso + cancelar
            opacity: root.ops.busy ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
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
            visible: !root.narrow
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
            visible: !root.narrow
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
            visible: !root.narrow
            icon: root.fileModel.showHidden ? "view-reveal-symbolic" : "view-conceal-symbolic"
            checked: root.fileModel.showHidden
            onActivated: root.fileModel.showHidden = !root.fileModel.showHidden
        }
        ToolButton { icon: "folder-new-symbolic"; visible: !root.narrow && !root.fileModel.isTrash; onActivated: root.newFolder() }
        ToolButton { // painel de prévia (F3)
            visible: !root.narrow
            icon: "view-dual-symbolic,view-sidebar-symbolic"
            checked: Settings.previewPanel
            onActivated: Settings.previewPanel = !Settings.previewPanel
        }

        ToolButton { // overflow no modo estreito
            visible: root.narrow
            icon: "view-more-symbolic,open-menu-symbolic,view-list-symbolic"
            onActivated: moreMenu.popup()
            GlassMenu {
                id: moreMenu
                GlassMenuItem { text: "Ícones"; tick: root.fileModel.viewMode === "grid"; onTriggered: root.fileModel.viewMode = "grid" }
                GlassMenuItem { text: "Lista"; tick: root.fileModel.viewMode === "list"; onTriggered: root.fileModel.viewMode = "list" }
                MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
                GlassMenuItem { text: "Ordenar por Nome"; tick: root.fileModel.sortKey === "name"; onTriggered: root.fileModel.sortBy("name") }
                GlassMenuItem { text: "Ordenar por Data"; tick: root.fileModel.sortKey === "modified"; onTriggered: root.fileModel.sortBy("modified") }
                GlassMenuItem { text: "Ordenar por Tamanho"; tick: root.fileModel.sortKey === "size"; onTriggered: root.fileModel.sortBy("size") }
                GlassMenuItem {
                    text: "Mostrar Arquivos Ocultos"
                    tick: root.fileModel.showHidden
                    onTriggered: root.fileModel.showHidden = !root.fileModel.showHidden
                }
                GlassMenuItem { text: "Nova Pasta"; visible: !root.fileModel.isTrash; onTriggered: root.newFolder() }
                GlassMenuItem { text: "Painel de Prévia"; shortcut: "F3"; tick: Settings.previewPanel; onTriggered: Settings.previewPanel = !Settings.previewPanel }
            }
        }

        SearchField {
            id: searchField
            compact: root.tiny
            anchors.verticalCenter: parent.verticalCenter
            fileModel: root.fileModel
            onEscaped: root.focusView()
        }
    }

    WindowControls {
        id: ctlRight
        visible: root.controlsRight
        window: root.window
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
    }
}
