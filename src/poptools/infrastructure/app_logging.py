from __future__ import annotations

import faulthandler
import logging
import sys
import threading
from dataclasses import dataclass
from datetime import datetime
from logging.handlers import QueueHandler, QueueListener
from pathlib import Path
from queue import Queue
from types import TracebackType
from typing import Any, BinaryIO

from PySide6.QtCore import QtMsgType, qInstallMessageHandler

from poptools.paths import AppPaths

LOGGER_NAME = "poptools"
LOG_MAX_BYTES = 5 * 1024 * 1024
NATIVE_FAULT_LOG = "native-faults.log"


class ReplacingFileHandler(logging.FileHandler):
    """Keep one bounded log file and replace its contents when it becomes full."""

    def __init__(self, path: Path, max_bytes: int) -> None:
        self.max_bytes = max_bytes
        super().__init__(path, mode="a", encoding="utf-8")

    def emit(self, record: logging.LogRecord) -> None:
        try:
            rendered = self.format(record) + self.terminator
            incoming_size = len(rendered.encode("utf-8", errors="replace"))
            current_size = Path(self.baseFilename).stat().st_size
            if current_size > 0 and current_size + incoming_size > self.max_bytes:
                if self.stream is not None:
                    self.stream.close()
                    self.stream = None
                Path(self.baseFilename).write_text("", encoding="utf-8")
            logging.FileHandler.emit(self, record)
        except Exception:
            self.handleError(record)


@dataclass
class LoggingSession:
    """Installed logging hooks, primarily exposed so tests can restore global state."""

    logger: logging.Logger
    handlers: tuple[logging.Handler, ...]
    queue_handler: QueueHandler
    listener: QueueListener
    log_queue: Queue[logging.LogRecord]
    previous_excepthook: Any
    previous_threading_excepthook: Any
    previous_unraisablehook: Any
    previous_qt_handler: Any
    native_fault_stream: BinaryIO
    faulthandler_was_enabled: bool

    def flush(self) -> None:
        self.log_queue.join()
        for handler in self.handlers:
            handler.flush()

    def close(self) -> None:
        sys.excepthook = self.previous_excepthook
        threading.excepthook = self.previous_threading_excepthook
        sys.unraisablehook = self.previous_unraisablehook
        qInstallMessageHandler(self.previous_qt_handler)
        if self.faulthandler_was_enabled:
            faulthandler.enable()
        else:
            faulthandler.disable()
        self.native_fault_stream.close()
        self.logger.removeHandler(self.queue_handler)
        self.listener.stop()
        for handler in self.handlers:
            handler.close()


def configure_application_logging(
    paths: AppPaths,
    *,
    max_bytes: int = LOG_MAX_BYTES,
) -> LoggingSession:
    """Write bounded application logs on a dedicated background thread."""

    paths.logs_dir.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(logging.INFO)
    logger.propagate = False

    # Reconfiguration is useful in tests and avoids duplicate lines after an in-process restart.
    for existing in tuple(logger.handlers):
        if getattr(existing, "_poptools_handler", False):
            logger.removeHandler(existing)
            existing.close()

    formatter = logging.Formatter(
        "%(asctime)s.%(msecs)03d %(levelname)s [%(threadName)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    app_handler = _replacing_handler(paths.logs_dir / "app.log", logging.INFO, max_bytes)
    fault_handler = _replacing_handler(
        paths.logs_dir / "faults.log", logging.ERROR, max_bytes
    )
    app_handler.setFormatter(formatter)
    fault_handler.setFormatter(formatter)
    log_queue: Queue[logging.LogRecord] = Queue()
    queue_handler = QueueHandler(log_queue)
    queue_handler._poptools_handler = True  # type: ignore[attr-defined]
    logger.addHandler(queue_handler)
    listener = QueueListener(
        log_queue, app_handler, fault_handler, respect_handler_level=True
    )
    listener.start()

    native_fault_path = paths.logs_dir / NATIVE_FAULT_LOG
    _replace_native_fault_log_if_full(native_fault_path, max_bytes)
    native_fault_stream = native_fault_path.open("ab", buffering=0)
    native_fault_stream.write(
        (
            f"\n--- PopTools native fault session "
            f"{datetime.now().isoformat(timespec='seconds')} "
            f"{threading.current_thread().name} ---\n"
        ).encode()
    )
    faulthandler_was_enabled = faulthandler.is_enabled()
    faulthandler.enable(file=native_fault_stream, all_threads=True)

    previous_excepthook = sys.excepthook
    previous_threading_excepthook = threading.excepthook
    previous_unraisablehook = sys.unraisablehook

    def flush_async_logs() -> None:
        log_queue.join()
        app_handler.flush()
        fault_handler.flush()

    def handle_exception(
        exception_type: type[BaseException],
        exception: BaseException,
        traceback: TracebackType | None,
    ) -> None:
        if issubclass(exception_type, KeyboardInterrupt):
            previous_excepthook(exception_type, exception, traceback)
            return
        logger.critical(
            "未处理异常导致应用故障",
            exc_info=(exception_type, exception, traceback),
        )
        flush_async_logs()

    def handle_thread_exception(args: threading.ExceptHookArgs) -> None:
        logger.critical(
            "后台线程发生未处理异常：%s",
            args.thread.name if args.thread else "unknown",
            exc_info=(args.exc_type, args.exc_value, args.exc_traceback),
        )
        flush_async_logs()

    def handle_unraisable(args: sys.UnraisableHookArgs) -> None:
        logger.error(
            "无法传递的异常：%s",
            args.err_msg or repr(args.object),
            exc_info=(type(args.exc_value), args.exc_value, args.exc_traceback),
        )
        flush_async_logs()

    sys.excepthook = handle_exception
    threading.excepthook = handle_thread_exception
    sys.unraisablehook = handle_unraisable

    qt_logger = logging.getLogger(f"{LOGGER_NAME}.qt")

    def handle_qt_message(message_type: QtMsgType, _context: Any, message: str) -> None:
        levels = {
            QtMsgType.QtDebugMsg: logging.DEBUG,
            QtMsgType.QtInfoMsg: logging.INFO,
            QtMsgType.QtWarningMsg: logging.WARNING,
            QtMsgType.QtCriticalMsg: logging.ERROR,
            QtMsgType.QtFatalMsg: logging.CRITICAL,
        }
        qt_logger.log(levels.get(message_type, logging.INFO), message)
        if message_type == QtMsgType.QtFatalMsg:
            flush_async_logs()

    previous_qt_handler = qInstallMessageHandler(handle_qt_message)
    logger.info("应用日志已启动；日志目录：%s", paths.logs_dir)
    logger.info("原生崩溃捕获已启动：%s", native_fault_path)
    return LoggingSession(
        logger=logger,
        handlers=(app_handler, fault_handler),
        queue_handler=queue_handler,
        listener=listener,
        log_queue=log_queue,
        previous_excepthook=previous_excepthook,
        previous_threading_excepthook=previous_threading_excepthook,
        previous_unraisablehook=previous_unraisablehook,
        previous_qt_handler=previous_qt_handler,
        native_fault_stream=native_fault_stream,
        faulthandler_was_enabled=faulthandler_was_enabled,
    )


def _replace_native_fault_log_if_full(path: Path, max_bytes: int) -> None:
    if not path.exists() or path.stat().st_size < max_bytes:
        return
    path.write_bytes(b"")


def _replacing_handler(
    path: Path, level: int, max_bytes: int
) -> ReplacingFileHandler:
    handler = ReplacingFileHandler(path, max_bytes)
    handler.setLevel(level)
    return handler
