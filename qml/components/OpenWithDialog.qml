import QtQuick
import QtQuick.Controls
import Folio

GlassPopup {
    id: root

    required property FileOps ops
    property string path
    property var apps: []

    function show(p) {
        path = p
        apps = ops.openWithApps(p)
        open()
    }

    contentItem: Column {
        spacing: 10
        Text {
            width: parent.width
            text: "Abrir com…"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
        }
        Text {
            visible: root.apps.length === 0
            width: parent.width
            text: "Nenhum aplicativo encontrado para este tipo de arquivo."
            color: Theme.textDim
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        ListView {
            width: parent.width
            height: Math.min(contentHeight, 280)
            visible: root.apps.length > 0
            clip: true
            model: root.apps
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 34; radius: 8
                color: area.containsMouse ? Theme.hover : "transparent"
                Row {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Image {
                        width: 20; height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        sourceSize: Qt.size(40, 40)
                        source: Theme.icon(modelData.icon + ",application-x-executable")
                    }
                    Text { text: modelData.name; color: Theme.text; font.pixelSize: Theme.fontSize; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.ops.openWith(root.path, modelData.id); root.close() }
                }
            }
        }
        Row {
            anchors.right: parent.right
            DialogButton { text: "Cancelar"; onClicked: root.close() }
        }
    }
}
