import QtQuick
import Folio

Item {
    id: root
    property string glyph // ícone simbólico gravado na pasta (Downloads, Documentos...)

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        source: "qrc:/qt/qml/Folio/assets/folder.svg"
        smooth: true
    }
    Image {
        visible: root.glyph !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.47
        width: root.width * 0.3; height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.glyph ? Theme.icon(root.glyph, "#2a6cc0") : ""
        opacity: 0.8
    }
}
