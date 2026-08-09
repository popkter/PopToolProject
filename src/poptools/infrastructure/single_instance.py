from __future__ import annotations

import hashlib
import json
import sys
import time
from collections.abc import Callable
from pathlib import Path

from PySide6.QtCore import QLockFile
from PySide6.QtNetwork import QLocalServer, QLocalSocket


class SingleInstanceLock:
    """Keep one application process active and let later launches activate it."""

    def __init__(self, lock_file: Path) -> None:
        lock_file.parent.mkdir(parents=True, exist_ok=True)
        self._lock = QLockFile(str(lock_file))
        identity = str(lock_file.resolve()).casefold().encode("utf-8")
        server_id = f"PopTools-{hashlib.sha256(identity).hexdigest()[:24]}"
        self._server_name = (
            f"/tmp/{server_id}.socket" if sys.platform == "darwin" else server_id
        )
        self._server: QLocalServer | None = None
        self._activation_handler: Callable[[dict[str, object]], None] | None = None
        self._activation_pending: dict[str, object] | None = None

    def try_acquire(self) -> bool:
        return self._lock.tryLock(0)

    def start_activation_server(self) -> bool:
        QLocalServer.removeServer(self._server_name)
        self._server = QLocalServer()
        self._server.newConnection.connect(self._on_new_connection)
        return self._server.listen(self._server_name)

    def activate_running_instance(
        self, payload: dict[str, object] | None = None, timeout_ms: int = 5000
    ) -> bool:
        deadline = time.monotonic() + timeout_ms / 1000
        while time.monotonic() < deadline:
            socket = QLocalSocket()
            socket.connectToServer(self._server_name)
            if socket.waitForConnected(250):
                message = payload or {"action": "activate"}
                socket.write(json.dumps(message, ensure_ascii=False).encode("utf-8"))
                socket.waitForBytesWritten(500)
                socket.disconnectFromServer()
                return True
            time.sleep(0.05)
        return False

    def set_activation_handler(
        self, handler: Callable[[dict[str, object]], None]
    ) -> None:
        self._activation_handler = handler
        if self._activation_pending:
            payload = self._activation_pending
            self._activation_pending = None
            handler(payload)

    def _on_new_connection(self) -> None:
        if self._server is None:
            return
        while self._server.hasPendingConnections():
            socket = self._server.nextPendingConnection()
            payload: dict[str, object] = {"action": "activate"}
            if socket is not None:
                if not socket.bytesAvailable():
                    socket.waitForReadyRead(250)
                raw_payload = bytes(socket.readAll())
                socket.disconnectFromServer()
                try:
                    payload = json.loads(raw_payload.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    payload = {"action": "activate"}
                if not isinstance(payload, dict):
                    payload = {"action": "activate"}
            if self._activation_handler is None:
                self._activation_pending = payload
            else:
                self._activation_handler(payload)

    def release(self) -> None:
        if self._server is not None:
            self._server.close()
            self._server = None
        if self._lock.isLocked():
            self._lock.unlock()
