from poptools.viewmodels import SettingsController
from poptools.viewmodels import settings_controller as controller_module


class RestartSubject:
    def __init__(self) -> None:
        self.configuration_status = ""

    def setStatus(self, value: str) -> None:
        self.configuration_status = value


def test_restart_application_starts_replacement_then_quits(monkeypatch) -> None:
    subject = RestartSubject()
    launches: list[tuple[str, list[str], str]] = []
    quits: list[bool] = []

    class FakeProcess:
        @staticmethod
        def startDetached(program: str, arguments: list[str], directory: str):
            launches.append((program, arguments, directory))
            return True, 123

    class FakeApplication:
        @staticmethod
        def quit() -> None:
            quits.append(True)

    monkeypatch.setattr(controller_module, "QProcess", FakeProcess)
    monkeypatch.setattr(controller_module, "QCoreApplication", FakeApplication)
    monkeypatch.setattr(controller_module.sys, "frozen", False, raising=False)

    assert SettingsController.restartApplication(subject) is True
    assert launches
    assert launches[0][1] == ["-m", "poptools"]
    assert quits == [True]


def test_restart_application_does_not_quit_when_relaunch_fails(monkeypatch) -> None:
    subject = RestartSubject()
    quits: list[bool] = []

    class FakeProcess:
        @staticmethod
        def startDetached(_program: str, _arguments: list[str], _directory: str):
            return False, 0

    class FakeApplication:
        @staticmethod
        def quit() -> None:
            quits.append(True)

    monkeypatch.setattr(controller_module, "QProcess", FakeProcess)
    monkeypatch.setattr(controller_module, "QCoreApplication", FakeApplication)

    assert SettingsController.restartApplication(subject) is False
    assert quits == []
    assert "\u91cd\u542f\u5931\u8d25" in subject.configuration_status
