"""Exercise the main window's actual resize handler with a controllable platform."""

import pytest
from PySide6.QtCore import QCoreApplication, QEvent, QObject, QPoint, QPointF, Qt, QUrl
from PySide6.QtGui import QMouseEvent
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtTest import QTest

from poptools.paths import package_root


@pytest.fixture
def resize_window(qapp):
    source = (package_root() / "ui/qml/Main.qml").read_text(encoding="utf-8")
    handler = source.split("    component ResizeHandle: MouseArea {", 1)[1]
    handler = "component ResizeHandle: MouseArea {" + handler.split(
        "\n    ResizeHandle {", 1
    )[0]
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        ("""
import QtQuick
import QtQuick.Window
Window {
    width: 400; height: 300; visible: true
    QtObject {
        id: window
        objectName: "geometry"
        property int x: 100
        property int y: 100
        property int width: 1200
        property int height: 900
        property int minimumWidth: 960
        property int minimumHeight: 720
        property int maximumWidth: 1500
        property int maximumHeight: 1100
        property int visibility: Window.Windowed
        property bool nativeSupported: false
        property int nativeEdges: 0
        property int geometryCalls: 0
        function startSystemResize(edges) {
            nativeEdges = edges
            return nativeSupported
        }
        function setGeometry(px, py, w, h) {
            geometryCalls++
            x = px; y = py; width = w; height = h
        }
    }
""" + handler + """
    ResizeHandle {
        objectName: "handle"
        anchors.fill: parent
        resizeEdges: Qt.BottomEdge | Qt.RightEdge
    }
}
""").encode(),
        QUrl(),
    )
    root = component.create()
    assert root is not None, [error.toString() for error in component.errors()]
    assert QTest.qWaitForWindowExposed(root)
    geometry = root.findChild(QObject, "geometry")
    handle = root.findChild(QObject, "handle")
    try:
        yield root, geometry, handle
    finally:
        root.close()
        root.deleteLater()


EDGES = [
    Qt.Edge.LeftEdge, Qt.Edge.RightEdge, Qt.Edge.TopEdge, Qt.Edge.BottomEdge,
    Qt.Edge.TopEdge | Qt.Edge.LeftEdge,
    Qt.Edge.TopEdge | Qt.Edge.RightEdge,
    Qt.Edge.BottomEdge | Qt.Edge.LeftEdge,
    Qt.Edge.BottomEdge | Qt.Edge.RightEdge,
]


def send_mouse(window, event_type, position):
    """Deliver one event without moving the OS cursor or pumping native events.

    QTest.mouseMove can also deliver pending platform moves on Windows runners.
    Exact geometry-call assertions require a controlled input event stream.
    """
    moving = event_type == QEvent.Type.MouseMove
    released = event_type == QEvent.Type.MouseButtonRelease
    event = QMouseEvent(
        event_type,
        QPointF(position),
        QPointF(window.mapToGlobal(position)),
        Qt.MouseButton.NoButton if moving else Qt.MouseButton.LeftButton,
        Qt.MouseButton.NoButton if released else Qt.MouseButton.LeftButton,
        Qt.KeyboardModifier.NoModifier,
    )
    QCoreApplication.sendEvent(window, event)


@pytest.mark.parametrize("edges", EDGES)
@pytest.mark.parametrize("native", [False, True])
def test_resize_all_edges(resize_window, edges, native):
    root, geometry, handle = resize_window
    handle.setProperty("resizeEdges", edges.value)
    geometry.setProperty("nativeSupported", native)
    send_mouse(root, QEvent.Type.MouseButtonPress, QPoint(120, 100))
    send_mouse(root, QEvent.Type.MouseMove, QPoint(160, 130))
    send_mouse(root, QEvent.Type.MouseButtonRelease, QPoint(160, 130))
    assert geometry.property("nativeEdges") == edges.value
    assert geometry.property("geometryCalls") == (0 if native else 1)
    left = bool(edges & Qt.Edge.LeftEdge) and not native
    right = bool(edges & Qt.Edge.RightEdge) and not native
    top = bool(edges & Qt.Edge.TopEdge) and not native
    bottom = bool(edges & Qt.Edge.BottomEdge) and not native
    assert geometry.property("x") == (140 if left else 100)
    assert geometry.property("y") == (130 if top else 100)
    assert geometry.property("width") == 1200 + (40 if right else -40 if left else 0)
    assert geometry.property("height") == 900 + (30 if bottom else -30 if top else 0)


@pytest.mark.parametrize("edges", EDGES[4:])
@pytest.mark.parametrize("expand", [False, True])
def test_corner_limits_keep_opposite_corner_fixed(resize_window, edges, expand):
    root, geometry, handle = resize_window
    handle.setProperty("resizeEdges", edges.value)
    left = bool(edges & Qt.Edge.LeftEdge)
    top = bool(edges & Qt.Edge.TopEdge)
    # Start close to either limit so an ordinary in-window drag crosses it.
    width, height = (1490, 1090) if expand else (970, 730)
    geometry.setProperty("width", width)
    geometry.setProperty("height", height)
    dx = 40 * (-1 if left else 1) * (1 if expand else -1)
    dy = 30 * (-1 if top else 1) * (1 if expand else -1)
    send_mouse(root, QEvent.Type.MouseButtonPress, QPoint(120, 100))
    target = QPoint(120 + dx, 100 + dy)
    send_mouse(root, QEvent.Type.MouseMove, target)
    send_mouse(root, QEvent.Type.MouseButtonRelease, target)
    expected_width, expected_height = (1500, 1100) if expand else (960, 720)
    assert geometry.property("width") == expected_width
    assert geometry.property("height") == expected_height
    assert geometry.property("x") == 100 + (width - expected_width if left else 0)
    assert geometry.property("y") == 100 + (height - expected_height if top else 0)
    assert geometry.property("geometryCalls") == 1


def test_maximized_window_disables_resize(resize_window):
    root, geometry, handle = resize_window
    geometry.setProperty("visibility", 4)  # QWindow.Maximized
    assert not handle.property("visible")
    send_mouse(root, QEvent.Type.MouseButtonPress, QPoint(120, 100))
    send_mouse(root, QEvent.Type.MouseMove, QPoint(160, 130))
    send_mouse(root, QEvent.Type.MouseButtonRelease, QPoint(160, 130))
    assert geometry.property("nativeEdges") == 0
    assert geometry.property("geometryCalls") == 0


def test_each_move_commits_both_axes_once(resize_window):
    root, geometry, handle = resize_window
    send_mouse(root, QEvent.Type.MouseButtonPress, QPoint(120, 100))
    for count, target in enumerate([QPoint(140, 110), QPoint(160, 130)], start=1):
        send_mouse(root, QEvent.Type.MouseMove, target)
        assert geometry.property("geometryCalls") == count
        assert geometry.property("width") == 1200 + target.x() - 120
        assert geometry.property("height") == 900 + target.y() - 100
        # Duplicate positions must not cause another geometry update.
        send_mouse(root, QEvent.Type.MouseMove, target)
        assert geometry.property("geometryCalls") == count
    send_mouse(root, QEvent.Type.MouseButtonRelease, QPoint(160, 130))
    send_mouse(root, QEvent.Type.MouseMove, QPoint(180, 150))
    assert geometry.property("geometryCalls") == 2
