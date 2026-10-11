import QtQuick
import QtQuick.Controls
import Folio

Popup {
    id: root
    anchors.centerIn: Overlay.overlay
    modal: true
    dim: true
    padding: 20
    width: Math.min(400, Overlay.overlay ? Overlay.overlay.width - 40 : 400)
    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
        radius: 14
        color: Theme.menuBg
        border.width: 1
        border.color: Theme.borderStrong
    }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 90 } }
}
