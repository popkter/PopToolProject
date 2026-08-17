from __future__ import annotations

from collections.abc import Callable

from PySide6.QtCore import QPoint, QRect, Qt
from PySide6.QtGui import (
    QColor,
    QCursor,
    QGuiApplication,
    QKeyEvent,
    QMouseEvent,
    QPainter,
    QPaintEvent,
    QPen,
    QPixmap,
)
from PySide6.QtWidgets import QWidget


class ScreenColorPickerOverlay(QWidget):
    """Transparent virtual-desktop overlay used to sample a screen pixel."""

    def __init__(
        self,
        picked: Callable[[str], None],
        cancelled: Callable[[], None],
    ) -> None:
        super().__init__(None)
        self._picked = picked
        self._cancelled = cancelled
        self._finished = False
        self._screenshots = [
            (screen.geometry(), screen.grabWindow(0))
            for screen in QGuiApplication.screens()
        ]
        virtual_geometry = QRect()
        for geometry, _pixmap in self._screenshots:
            virtual_geometry = virtual_geometry.united(geometry)

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.Tool
            | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setGeometry(virtual_geometry)
        self.setCursor(self._eyedropper_cursor())

    def begin(self) -> None:
        self.show()
        self.raise_()
        self.activateWindow()
        self.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
        self.grabMouse()
        self.grabKeyboard()

    def paintEvent(self, event: QPaintEvent) -> None:  # noqa: N802
        # A nearly transparent painted pixel makes the native Windows window
        # participate in hit testing while remaining visually transparent.
        painter = QPainter(self)
        painter.fillRect(event.rect(), QColor(0, 0, 0, 1))

    def mousePressEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            color = self._color_at(event.globalPosition().toPoint())
            if color.isValid():
                self._finish(color.name(QColor.NameFormat.HexRgb).upper())
                return
        if event.button() == Qt.MouseButton.RightButton:
            self._cancel()

    def keyPressEvent(self, event: QKeyEvent) -> None:  # noqa: N802
        if event.key() == Qt.Key.Key_Escape:
            self._cancel()
            return
        super().keyPressEvent(event)

    def closeEvent(self, event) -> None:  # noqa: N802, ANN001
        if not self._finished:
            self._finished = True
            self._cancelled()
        super().closeEvent(event)

    def _color_at(self, global_position: QPoint) -> QColor:
        for geometry, pixmap in self._screenshots:
            if not geometry.contains(global_position):
                continue
            ratio = pixmap.devicePixelRatio()
            local_x = round((global_position.x() - geometry.x()) * ratio)
            local_y = round((global_position.y() - geometry.y()) * ratio)
            image = pixmap.toImage()
            if 0 <= local_x < image.width() and 0 <= local_y < image.height():
                return image.pixelColor(local_x, local_y)
        return QColor()

    def _finish(self, color: str) -> None:
        if self._finished:
            return
        self._finished = True
        self.releaseKeyboard()
        self.releaseMouse()
        self.hide()
        self._picked(color)
        self.deleteLater()

    def _cancel(self) -> None:
        if self._finished:
            return
        self._finished = True
        self.releaseKeyboard()
        self.releaseMouse()
        self.hide()
        self._cancelled()
        self.deleteLater()

    @staticmethod
    def _eyedropper_cursor() -> QCursor:
        pixmap = QPixmap(32, 32)
        pixmap.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(QColor("#FFFFFF"), 5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(9, 23, 22, 10)
        painter.setPen(QPen(QColor("#25232A"), 2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(9, 23, 22, 10)
        painter.setBrush(QColor("#4B48D6"))
        painter.drawEllipse(19, 5, 8, 8)
        painter.setBrush(QColor("#FFFFFF"))
        painter.drawEllipse(5, 21, 7, 7)
        painter.end()
        return QCursor(pixmap, 8, 25)
