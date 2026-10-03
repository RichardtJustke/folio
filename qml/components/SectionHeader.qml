import QtQuick
import Folio

Item {
    property string title

    height: Theme.sectionHeaderHeight

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        text: parent.title
        color: Theme.textDim
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10 }
        height: 1
        color: Theme.border
    }
}
