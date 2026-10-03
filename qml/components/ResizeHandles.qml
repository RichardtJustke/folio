import QtQuick

// bordas para redimensionar janela sem decoração (xdg_toplevel.resize)
Item {
    id: root
    required property var window
    property int grip: 6

    anchors.fill: parent
    visible: window.visibility !== Window.Maximized && window.visibility !== Window.FullScreen

    component Edge: MouseArea {
        property int edges
        hoverEnabled: true
        onPressed: root.window.startSystemResize(edges)
    }

    Edge { edges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor; x: 0; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip }
    Edge { edges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor; x: parent.width - root.grip; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip }
    Edge { edges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor; x: root.grip; y: 0; width: parent.width - 2 * root.grip; height: root.grip }
    Edge { edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor; x: root.grip; y: parent.height - root.grip; width: parent.width - 2 * root.grip; height: root.grip }
    Edge { edges: Qt.TopEdge | Qt.LeftEdge; cursorShape: Qt.SizeFDiagCursor; width: root.grip * 2; height: width }
    Edge { edges: Qt.TopEdge | Qt.RightEdge; cursorShape: Qt.SizeBDiagCursor; x: parent.width - width; width: root.grip * 2; height: width }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge; cursorShape: Qt.SizeBDiagCursor; y: parent.height - height; width: root.grip * 2; height: width }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; cursorShape: Qt.SizeFDiagCursor; x: parent.width - width; y: parent.height - height; width: root.grip * 2; height: width }
}
