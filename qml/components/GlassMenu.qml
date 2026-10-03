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

    delegate: GlassMenuItem {}
}
