from datetime import datetime

from PySide6.QtCore import QCoreApplication, QEventLoop, QTimer

from poptools.infrastructure.config_store import ConfigStore
from poptools.paths import AppPaths
from poptools.viewmodels.update_controller import UpdateController


def local_timestamp(year, month, day, hour=0, minute=0):
    return datetime(year, month, day, hour, minute).astimezone().timestamp()


def make_controller(tmp_path, now):
    QCoreApplication.instance() or QCoreApplication([])
    store = ConfigStore(AppPaths(tmp_path))

    def clock():
        return now[0]

    controller = UpdateController(store, auto_check_enabled=True, clock=clock)
    calls = []
    controller._start_check = lambda manual: calls.append(manual) or True
    return store, controller, calls


def test_daily_checks_once_per_local_calendar_day(tmp_path):
    now = [local_timestamp(2026, 9, 10, 0, 1)]
    store, controller, calls = make_controller(tmp_path, now)
    store.set_update_check_frequency("daily")
    store.set_last_auto_update_check_at(local_timestamp(2026, 9, 9, 23, 59))

    assert controller.checkForUpdatesAutomatically()
    assert store.last_auto_update_check_at() == now[0]
    assert not controller.checkForUpdatesAutomatically()
    now[0] = local_timestamp(2026, 9, 11, 0, 1)
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False, False]
    controller.shutdown()


def test_weekly_checks_once_per_monday_based_week(tmp_path):
    now = [local_timestamp(2026, 9, 9, 12)]  # Wednesday
    store, controller, calls = make_controller(tmp_path, now)
    store.set_update_check_frequency("weekly")
    store.set_last_auto_update_check_at(local_timestamp(2026, 9, 6, 23, 59))

    assert controller.checkForUpdatesAutomatically()
    now[0] = local_timestamp(2026, 9, 13, 23, 59)  # Sunday, same week
    assert not controller.checkForUpdatesAutomatically()
    now[0] = local_timestamp(2026, 9, 14, 0, 1)  # Next Monday
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False, False]
    controller.shutdown()


def test_never_disables_auto_but_manual_check_still_starts(tmp_path):
    now = [local_timestamp(2026, 9, 10, 12)]
    store, controller, calls = make_controller(tmp_path, now)
    assert controller.updateCheckFrequency == "weekly"
    controller.setUpdateCheckFrequency("never")
    assert not controller.checkForUpdatesAutomatically()
    assert controller.checkForUpdates()
    assert calls == [True]
    assert ConfigStore(AppPaths(tmp_path)).update_check_frequency() == "never"
    controller.shutdown()


def test_manual_success_does_not_consume_auto_check_period(tmp_path):
    now = [local_timestamp(2026, 9, 10, 12)]
    store, controller, calls = make_controller(tmp_path, now)
    store.set_update_check_frequency("daily")
    controller._check_is_manual = True

    controller._on_check_completed(None, "")

    assert store.last_update_check_at() == now[0]
    assert store.last_auto_update_check_at() == 0.0
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False]
    controller.shutdown()


def test_failed_auto_check_is_not_retried_until_next_period(tmp_path):
    now = [local_timestamp(2026, 9, 10, 12)]
    store, controller, calls = make_controller(tmp_path, now)
    store.set_update_check_frequency("daily")

    assert controller.checkForUpdatesAutomatically()
    controller._on_check_completed(None, "network error")
    assert not controller.checkForUpdatesAutomatically()
    now[0] = local_timestamp(2026, 9, 11, 0, 1)
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False, False]
    controller.shutdown()


def test_legacy_success_timestamp_initializes_auto_schedule(tmp_path):
    store = ConfigStore(AppPaths(tmp_path))
    legacy_timestamp = local_timestamp(2026, 9, 10, 8)
    config = store.load_config()
    config["app"].pop("last_auto_update_check_at")
    config["app"]["last_update_check_at"] = legacy_timestamp
    store.save_config(config)

    assert store.last_auto_update_check_at() == legacy_timestamp
    assert ConfigStore(AppPaths(tmp_path)).last_auto_update_check_at() == legacy_timestamp


def test_missing_invalid_and_future_schedule_values_are_safe(tmp_path):
    now = [local_timestamp(2026, 9, 10, 12)]
    store, controller, calls = make_controller(tmp_path, now)
    config = store.load_config()
    config["app"]["update_check_frequency"] = "sometimes"
    config["app"]["last_auto_update_check_at"] = "invalid"
    store.save_config(config)

    assert controller.updateCheckFrequency == "weekly"
    assert controller.checkForUpdatesAutomatically()
    assert calls == [False]

    store.set_last_auto_update_check_at(local_timestamp(2026, 9, 20, 12))
    now[0] = local_timestamp(2026, 9, 14, 12)
    assert not controller.checkForUpdatesAutomatically()
    controller.shutdown()


def test_manual_check_uses_saved_beta_channel_and_reports_result(tmp_path):
    QCoreApplication.instance() or QCoreApplication([])
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
