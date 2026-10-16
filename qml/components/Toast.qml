import QtQuick
import Folio

Rectangle {
    id: root

    property bool isError: false
    property string actionLabel: ""
    property var actionCallback: null

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

    function show(message, error, actionLabel, actionFn) {
        label.text = message
        isError = !!error
        root.actionLabel = actionLabel || ""
        root.actionCallback = actionFn || null
        opacity = 1
        actionBtn.opacity = actionLabel ? 1 : 0
        timer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    width: Math.min(contentRow.implicitWidth + 24, parent.width - 40)
    height: contentRow.implicitHeight + 16
    radius: Math.min(height / 2, 16)
    color: Theme.menuBg
    border.width: 1
    border.color: isError ? Theme.danger : Theme.borderStrong
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 10

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.parent ? root.parent.width - 100 : 400)
            color: Theme.text
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: actionBtn
            anchors.verticalCenter: parent.verticalCenter
            width: actionText.implicitWidth + 16
            height: 22
            radius: 11
            color: actionArea.containsMouse ? Theme.hover : "transparent"
            border.width: 1
            border.color: Theme.border
            opacity: root.actionLabel ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }

            Text {
                id: actionText
                anchors.centerIn: parent
                text: root.actionLabel
                color: Theme.accent
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.actionCallback) root.actionCallback()
                    root.opacity = 0
                }
            }
        }
    }

    Timer { id: timer; interval: root.isError ? 4500 : 2200; onTriggered: root.opacity = 0 }
}