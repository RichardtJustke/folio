import QtQuick
import QtQuick.Controls
import QtMultimedia
import Folio

// Visualização rápida (Espaço): imagem, texto, miniatura ou ícone + metadados.
// Não rouba o foco: as setas continuam navegando na vista e o preview acompanha.
Item {
    id: root

    required property FileOps ops
    property var entry: ({})
    property bool shown: false
    property real originX: 0 // centro da miniatura de origem, relativo ao centro da janela
    property real originY: 0

    readonly property bool hasEntry: entry !== undefined && entry.path !== undefined

    anchors.fill: parent
    visible: opacity > 0
    opacity: shown && hasEntry ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: root.shown = false; onWheel: w => w.accepted = true }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shown ? 0 : root.originX
        anchors.verticalCenterOffset: root.shown ? 0 : root.originY
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
        width: Math.min(parent.width * 0.75, 960)
        height: Math.min(parent.height * 0.82, 720)
        radius: 14
        color: Theme.menuBg
        border.width: 1
        border.color: Theme.borderStrong
        scale: root.shown ? 1 : (root.originX === 0 && root.originY === 0 ? 0.96 : 0.25)
        Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent } // não fecha ao clicar no painel

        Text {
            id: titleText
            anchors { left: parent.left; right: closeBtn.left; top: parent.top; margins: 14 }
            text: root.hasEntry ? root.entry.name : ""
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.Bold
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: closeBtn
            anchors { right: parent.right; top: parent.top; margins: 10 }
            width: 24; height: 24; radius: 12
            color: closeArea.containsMouse ? Theme.hover : "transparent"
            Image {
                anchors.centerIn: parent
                width: 12; height: 12
                sourceSize: Qt.size(24, 24)
                source: Theme.icon("window-close-symbolic", Theme.textDim)
            }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.shown = false }
        }

        Loader {
            id: content
            anchors { left: parent.left; right: parent.right; top: titleText.bottom; bottom: footer.top; margins: 16 }
            active: root.hasEntry && root.visible
            sourceComponent: {
                if (!root.hasEntry) return null
                if (root.entry.isDir) return iconComp
                switch (root.entry.preview) {
                case "image": return root.entry.mime === "image/gif" ? gifComp : imageComp
                case "text": return textComp
                case "thumb": return thumbComp
                default:
                    if (root.entry.mime && (root.entry.mime.startsWith("video/") || root.entry.mime.startsWith("audio/")))
                        return mediaComp
                    return iconComp
                }
            }
        }

        Text {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            font.pixelSize: 12
            elide: Text.ElideMiddle
            text: !root.hasEntry ? ""
                : [root.entry.typeName,
                   root.entry.isDir ? Theme.itemsLabel(root.entry.itemCount) : Theme.sizeLabel(root.entry.size),
                   "Modificado: " + Theme.dateLabel(root.entry.modified)].join("  ·  ")
        }
    }

    Component {
        id: imageComp
        Image {
            source: root.ops.fileUrl(root.entry.path)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            autoTransform: true
            sourceSize: Qt.size(2048, 2048)
            smooth: true
            mipmap: true
        }
    }
    Component {
        id: gifComp
        AnimatedImage {
            source: root.ops.fileUrl(root.entry.path)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }
    Component {
        id: thumbComp
        Image {
            source: "image://thumb/" + root.entry.thumb
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(256, 256)
            smooth: true
        }
    }
    Component {
        id: textComp
        ScrollView {
            clip: true
            TextArea {
                readOnly: true
                text: root.ops.readText(root.entry.path)
                color: Theme.text
                font.family: "monospace"
                font.pixelSize: 12
                wrapMode: TextEdit.NoWrap
                selectByMouse: true
                selectionColor: Theme.accent
                background: Rectangle { radius: 8; color: Qt.rgba(0, 0, 0, 0.25) }
            }
        }
    }
    Component {
        id: iconComp
        Item {
            FolderIcon {
                visible: root.entry.isDir
                anchors.centerIn: parent
                width: 192; height: 192
                glyph: root.entry.glyph || ""
            }
            Image {
                visible: !root.entry.isDir
                anchors.centerIn: parent
                width: 160; height: 160
                sourceSize: Qt.size(256, 256)
                source: root.entry.isDir ? ""
                      : Settings.fileIcons === "system" ? Theme.icon(root.entry.icon) + "&pack=0"
                      : Theme.fileIcon(root.entry.icon, root.entry.name)
            }
        }
    }

    // vídeo/áudio com controles simples
    Component {
        id: mediaComp
        Item {
            anchors.fill: parent

            MediaPlayer {
                id: player
                source: root.ops.fileUrl(root.entry.path)
                audioOutput: AudioOutput { id: audioOut; volume: 1.0 }
                videoOutput: videoOut
                onErrorOccurred: {
                    // fallback: ícone grande se não puder tocar
                    iconFallback.visible = true
                    playBtn.visible = false
                    pauseBtn.visible = false
                }
            }
            VideoOutput {
                id: videoOut
                anchors.fill: parent
                visible: player.hasVideo
            }
            FolderIcon {
                id: iconFallback
                visible: !player.hasVideo
                anchors.centerIn: parent
                width: 128; height: 128
                glyph: ""
            }
            Image {
                visible: !player.hasVideo
                anchors.centerIn: parent
                width: 128; height: 128
                sourceSize: Qt.size(256, 256)
                source: Theme.fileIcon(root.entry.icon, root.entry.name)
            }

            Row {
                id: controls
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                spacing: 8

                Rectangle {
                    id: playBtn
                    width: 40; height: 32; radius: 16
                    color: playArea.containsMouse ? Theme.accent : Theme.overlay(0.12)
                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        sourceSize: Qt.size(32, 32)
                        source: Theme.icon("media-playback-start-symbolic", "white")
                    }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; onClicked: player.play() }
                }
                Rectangle {
                    id: pauseBtn
                    width: 40; height: 32; radius: 16
                    color: pauseArea.containsMouse ? Theme.accent : Theme.overlay(0.12)
                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        sourceSize: Qt.size(32, 32)
                        source: Theme.icon("media-playback-pause-symbolic", "white")
                    }
                    MouseArea { id: pauseArea; anchors.fill: parent; hoverEnabled: true; onClicked: player.pause() }
                }
                Rectangle {
                    width: 40; height: 32; radius: 16
                    color: stopArea.containsMouse ? Theme.accent : Theme.overlay(0.12)
                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        sourceSize: Qt.size(32, 32)
                        source: Theme.icon("media-playback-stop-symbolic", "white")
                    }
                    MouseArea { id: stopArea; anchors.fill: parent; hoverEnabled: true; onClicked: player.stop() }
                }
            }

            Component.onCompleted: player.play()
        }
    }
}
