from pathlib import Path

from pytestqt.qtbot import QtBot

from poptools.infrastructure.single_instance import SingleInstanceLock


def test_only_one_lock_can_be_acquired(tmp_path: Path) -> None:
    lock_file = tmp_path / "poptools.lock"
    first = SingleInstanceLock(lock_file)
    second = SingleInstanceLock(lock_file)

    assert first.try_acquire()
    assert not second.try_acquire()

    first.release()
    assert second.try_acquire()
    second.release()


def test_release_can_be_called_without_acquiring(tmp_path: Path) -> None:
    instance_lock = SingleInstanceLock(tmp_path / "poptools.lock")

    instance_lock.release()


def test_second_instance_requests_activation(tmp_path: Path, qtbot: QtBot) -> None:
    lock_file = tmp_path / "poptools.lock"
    primary = SingleInstanceLock(lock_file)
    secondary = SingleInstanceLock(lock_file)
    activations: list[str] = []

    assert primary.try_acquire()
    assert primary.start_activation_server()
    primary.set_activation_handler(lambda: activations.append("activate"))
    assert not secondary.try_acquire()
    assert secondary.activate_running_instance()

    qtbot.waitUntil(lambda: activations == ["activate"])
    primary.release()