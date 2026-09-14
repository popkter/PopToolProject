"""Exercise Windows REPL input boundaries without opening a console."""
import sys
import unittest
from collections import deque
from pathlib import Path
from types import SimpleNamespace as NS

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'resources' / 'plugin-bootstrap'))
from _pyrepl.windows_console import WindowsConsole, KEY_EVENT
from repl_unicode import install


def key(character, down=True, vk=0):
    return NS(EventType=KEY_EVENT, Event=NS(KeyEvent=NS(
        bKeyDown=down, wVirtualKeyCode=vk, dwControlKeyState=0,
        uChar=NS(UnicodeChar=character))))


class UnicodeInputTests(unittest.TestCase):
    def setUp(self):
        self.original = WindowsConsole._read_input
        self.records = deque()
        WindowsConsole._read_input = lambda console, block=True: self.records.popleft() if self.records else None
        install()
        self.console = WindowsConsole.__new__(WindowsConsole)

    def tearDown(self):
        WindowsConsole._read_input = self.original

    def read(self):
        return self.console._read_input(False)

    def test_keydown_surrogates(self):
        self.records.extend([key('\ud83d'), key('\ude42')])
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, '🙂')

    def test_alt_release_and_intervening_modifiers(self):
        self.records.extend([key('\ud83d', False, 18), key('\0', True, 18),
                             key('\0', False, 102), key('\ude42', False, 18)])
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, '\0')
        self.assertFalse(self.read().Event.KeyEvent.bKeyDown)
        result = self.read().Event.KeyEvent
        self.assertTrue(result.bKeyDown)
        self.assertEqual(result.uChar.UnicodeChar, '🙂')

    def test_partial_pair_nonblocking(self):
        self.records.append(key('\ud83d'))
        self.assertIsNone(self.read())
        self.records.append(key('\ude42'))
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, '🙂')

    def test_unpaired_units_do_not_drop_following_text(self):
        self.records.extend([key('\ude42'), key('\ud83d'), key('a')])
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, '\ufffd')
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, '\ufffd')
        self.assertEqual(self.read().Event.KeyEvent.uChar.UnicodeChar, 'a')

    def test_regular_keyup_is_not_promoted(self):
        self.records.extend([key('a'), key('a', False, 65)])
        self.assertTrue(self.read().Event.KeyEvent.bKeyDown)
        self.assertFalse(self.read().Event.KeyEvent.bKeyDown)

    def test_install_is_idempotent(self):
        installed = WindowsConsole._read_input
        install()
        self.assertIs(WindowsConsole._read_input, installed)


if __name__ == '__main__':
    unittest.main()
