"""Platform-specific presentation services exposed to QML."""

from __future__ import annotations

import html
import sys

from PySide6.QtCore import Property, QObject, QPoint, QRect, Slot
from PySide6.QtWidgets import QToolTip


class PlatformUiController(QObject):
    """Bridge small native UI affordances without changing the global QML style."""

    @Property(bool, constant=True)
    def nativeWindowFrameEnabled(self) -> bool:  # noqa: N802 - public QML API
        return sys.platform == "darwin"

    @Property(bool, constant=True)
    def nativeToolTipsEnabled(self) -> bool:  # noqa: N802 - public QML API
        return sys.platform == "darwin"

    @Slot(str, int, int, int)
    def showNativeToolTip(  # noqa: N802 - public QML API
        self,
        text: str,
        global_x: int,
        global_y: int,
        timeout: int,
    ) -> None:
        if not self.nativeToolTipsEnabled or not text:
            return
        escaped_text = html.escape(text).replace("\n", "<br>")
        rich_text = f"<p style='white-space:pre-wrap'>{escaped_text}</p>"
        QToolTip.showText(
            QPoint(global_x, global_y),
            rich_text,
            None,
            QRect(),
            timeout if timeout > 0 else -1,
        )

    @Slot()
    def hideNativeToolTip(self) -> None:  # noqa: N802 - public QML API
        if self.nativeToolTipsEnabled:
            QToolTip.hideText()
