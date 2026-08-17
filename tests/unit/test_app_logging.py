from __future__ import annotations

import faulthandler
import logging

from poptools.infrastructure.app_logging import configure_application_logging
from poptools.paths import AppPaths


def test_application_logging_writes_runtime_and_fault_logs(tmp_path) -> None:
    session = configure_application_logging(AppPaths(tmp_path), max_bytes=10_000)
    try:
        logger = logging.getLogger("poptools.test")
        logger.info("runtime marker")
        logger.error("fault marker")
        session.flush()

        app_log = (tmp_path / "logs" / "app.log").read_text(encoding="utf-8")
        fault_log = (tmp_path / "logs" / "faults.log").read_text(encoding="utf-8")
        assert "runtime marker" in app_log
        assert "fault marker" in app_log
        assert "runtime marker" not in fault_log
        assert "fault marker" in fault_log
    finally:
        session.close()


def test_application_log_replaces_contents_when_full(tmp_path) -> None:
    session = configure_application_logging(AppPaths(tmp_path), max_bytes=300)
    try:
        logger = logging.getLogger("poptools.test")
        for index in range(100):
            logger.info("entry %s %s", index, "x" * 80)
        session.flush()

        app_logs = list((tmp_path / "logs").glob("app.log*"))
        assert len(app_logs) == 1
        assert app_logs[0].stat().st_size <= 500
        app_log = app_logs[0].read_text(encoding="utf-8")
        assert "entry 99" in app_log
        assert "entry 0 " not in app_log
    finally:
        session.close()


def test_unhandled_exception_hook_records_traceback(tmp_path) -> None:
    session = configure_application_logging(AppPaths(tmp_path), max_bytes=10_000)
    try:
        try:
            raise RuntimeError("crash marker")
        except RuntimeError as exc:
            session_logger_hook = __import__("sys").excepthook
            session_logger_hook(type(exc), exc, exc.__traceback__)
        session.flush()

        fault_log = (tmp_path / "logs" / "faults.log").read_text(encoding="utf-8")
        assert "未处理异常导致应用故障" in fault_log
        assert "RuntimeError: crash marker" in fault_log
    finally:
        session.close()


def test_native_fault_log_captures_python_thread_dump(tmp_path) -> None:
    session = configure_application_logging(AppPaths(tmp_path), max_bytes=10_000)
    try:
        faulthandler.dump_traceback(file=session.native_fault_stream, all_threads=True)
        native_fault_log = (tmp_path / "logs" / "native-faults.log").read_text(
            encoding="utf-8"
        )
        assert "PopTools native fault session" in native_fault_log
        assert "test_native_fault_log_captures_python_thread_dump" in native_fault_log
    finally:
        session.close()
