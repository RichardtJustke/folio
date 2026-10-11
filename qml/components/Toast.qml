import QtQuick
import Folio

Rectangle {
    id: root

    property bool isError: false

    property real shakeX: 0
    transform: Translate { x: root.shakeX; y: (1 - root.opacity) * 14 }

    function shake() {
        if (!Theme.motion) return
        shakeAnim.restart()
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -7; duration: Theme.dur(60) }
        NumberAnimation { target: root; property: "shakeX"; to: 7; duration: Theme.dur(90) }
        NumberAnimation { target: root; property: "shakeX"; to: -4; duration: Theme.dur(80) }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Theme.dur(60) }
    }

    function show(message, error) {
        label.text = message
        isError = !!error
        opacity = 1
        timer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    width: Math.min(label.implicitWidth + 32, parent.width - 40)
    height: label.implicitHeight + 16
    radius: Math.min(height / 2, 16)
    color: Theme.menuBg
    border.width: 1
    border.color: isError ? Theme.danger : Theme.borderStrong
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.parent.width - 72)
        color: Theme.text
        font.pixelSize: Theme.fontSize
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }

    Timer { id: timer; interval: root.isError ? 4500 : 2200; onTriggered: root.opacity = 0 }
}
