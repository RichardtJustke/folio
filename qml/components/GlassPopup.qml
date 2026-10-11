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
    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.35)
        Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
    }
    Overlay.modeless: Rectangle { color: "transparent" }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(180); easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.dur(180); easing.type: Easing.OutCubic }
        NumberAnimation { property: "y"; from: root.y + 8; to: root.y; duration: Theme.dur(180); easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(120) }
        NumberAnimation { property: "scale"; to: 0.98; duration: Theme.dur(120) }
    }
}
