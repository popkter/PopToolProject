"""Keep UTF-16 input pairs intact for the managed CPython 3.13 Windows REPL.

Windows KEY_EVENT_RECORD contains one UTF-16 code unit. ConPTY may deliver
these on Alt key-up, which CPython 3.13 ignores. Its VT input scanner also
encodes each record separately (related: CPython issue 136595).
"""
from types import SimpleNamespace


def install():
    from _pyrepl.windows_console import WindowsConsole, KEY_EVENT

    original = WindowsConsole._read_input
    if getattr(original, "_uterminal_unicode", False):
        return

    def with_character(record, text):
        key = record.Event.KeyEvent
        return SimpleNamespace(EventType=record.EventType, Event=SimpleNamespace(
            KeyEvent=SimpleNamespace(bKeyDown=True,
                wVirtualKeyCode=key.wVirtualKeyCode,
                dwControlKeyState=key.dwControlKeyState,
                uChar=SimpleNamespace(UnicodeChar=text))))

    def read_input(self, block=True):
        while True:
            record = getattr(self, "_uterminal_queued_record", None)
            self._uterminal_queued_record = None
            if record is None:
                record = original(self, block)
            if record is None or record.EventType != KEY_EVENT:
                return record
            key = record.Event.KeyEvent
            character = key.uChar.UnicodeChar
            value = ord(character)
            # ConPTY can use the console's Alt+numpad input convention:
            # the completed character arrives on VK_MENU key-up. Ordinary
            # key-up records must still be ignored to avoid doubled input.
            if not key.bKeyDown and not (key.wVirtualKeyCode == 18 and value):
                return record
            if not value:
                return record
            pending = getattr(self, "_uterminal_high_surrogate", None)
            self._uterminal_high_surrogate = None
            if pending is not None:
                if 0xDC00 <= value <= 0xDFFF:
                    return with_character(record, chr(0x10000 + ((pending - 0xD800) << 10) + value - 0xDC00))
                self._uterminal_queued_record = record
                return with_character(record, "\ufffd")
            if 0xD800 <= value <= 0xDBFF:
                self._uterminal_high_surrogate = value
                continue
            if 0xDC00 <= value <= 0xDFFF:
                return with_character(record, "\ufffd")
            return record if key.bKeyDown else with_character(record, character)

    read_input._uterminal_unicode = True
    WindowsConsole._read_input = read_input
