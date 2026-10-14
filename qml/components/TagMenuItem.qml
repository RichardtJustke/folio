import QtQuick
import QtQuick.Controls
import Folio

// Linha de bolinhas coloridas no menu: clicar liga/desliga a etiqueta nos itens selecionados.
MenuItem {
    id: root

    required property var paths
    required property FileOps ops
    property int revision // muda quando a pasta é relida (recalcula as marcas)
    signal changed

    // etiquetas que TODOS os selecionados têm (bolinha marcada)
    readonly property var common: {
        if (revision < 0 || !paths.length) return []
        let c = ops.tagsOf(paths[0])
        for (const p of paths.slice(1, 200)) { const t = ops.tagsOf(p); c = c.filter(x => t.includes(x)) }
        return c
    }

    implicitHeight: visible ? 34 : 0
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: false
    background: Item {}

    contentItem: Row {
        spacing: 8
        Repeater {
            model: Theme.tagNames
            delegate: Rectangle {
                required property string modelData
                readonly property bool on: root.common.includes(modelData)
                width: 20; height: 20; radius: 10
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                color: Theme.tagColor(modelData)
                border.width: on || dotArea.containsMouse ? 2 : 0
                border.color: Theme.text
                scale: dotArea.containsMouse ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur(100) } }
                Text { // ✓ na etiqueta ligada
                    visible: parent.on
                    anchors.centerIn: parent
                    text: "✓"
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    ToolTip.visible: containsMouse
                    ToolTip.text: parent.modelData
                    ToolTip.delay: 400
                    onClicked: {
                        root.ops.toggleTag(root.paths, parent.modelData)
                        root.changed()
                        root.menu.close()
                    }
                }
            }
        }
    }
}
