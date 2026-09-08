from PySide6.QtCore import QCoreApplication, QEventLoop, QTimer

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths
from poptools.viewmodels.update_controller import UpdateController


def test_frequency_persists_and_controls_due_checks(tmp_path):
    app = QCoreApplication.instance() or QCoreApplication([])
    store = ConfigStore(AppPaths(tmp_path))
    now = 2_000_000.0
    store.set_last_update_check_at(now - 86400 * 2)
    controller = UpdateController(store, auto_check_enabled=True, clock=lambda: now)
    calls = []
    controller._start_check = lambda manual: calls.append(manual) or True
    assert controller.updateCheckFrequency == "weekly"
    assert not controller.checkForUpdatesAutomatically()
    controller.setUpdateCheckFrequency("daily")
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False]
    controller.setUpdateCheckFrequency("never")
    assert not controller.checkForUpdatesAutomatically()
    assert controller.checkForUpdates()
    assert calls == [False, True]
    assert ConfigStore(AppPaths(tmp_path)).update_check_frequency() == "never"
    controller.shutdown()


def test_manual_check_uses_saved_beta_channel_and_reports_result(tmp_path):
    app = QCoreApplication.instance() or QCoreApplication([])
    store = ConfigStore(AppPaths(tmp_path))
    calls = []

    class Client:
        def latest_release(self, include_prereleases):
            calls.append(include_prereleases)
            return None

    controller = UpdateController(store, client=Client(), auto_check_enabled=False)
    controller.setUpdateCheckFrequency("never")
    assert controller.setPrereleaseUpdatesEnabled(True)
    assert ConfigStore(AppPaths(tmp_path)).prerelease_updates_enabled()
    loop = QEventLoop()
    controller.stateChanged.connect(lambda: loop.quit() if controller.state != "checking" else None)
    assert controller.checkForUpdates()
    QTimer.singleShot(3000, loop.quit)
    loop.exec()
    assert calls == [True]
    assert controller.status == "当前已是最新版本"
    controller.shutdown()
