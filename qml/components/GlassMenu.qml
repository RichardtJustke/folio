import QtQuick
import QtQuick.Controls
import Folio

Menu {
    id: root
    padding: 5
    implicitWidth: 230

    background: Rectangle {
        implicitWidth: 230
        radius: 10
        color: Theme.menuBg
        border.width: 1
        border.color: Theme.borderStrong
    }

    transformOrigin: Popup.TopLeft
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(140); easing.type: Easing.OutQuad }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.dur(140); easing.type: Easing.OutQuad }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(100) }
    }

    delegate: GlassMenuItem {}
}
