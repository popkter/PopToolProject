#include <assert.h>
#include <stdint.h>
#include <string.h>

#include <vterm.h>

int main(void)
{
    VTerm *terminal = vterm_new(24, 80);
    assert(terminal != NULL);
    vterm_set_utf8(terminal, 1);

    VTermScreen *screen = vterm_obtain_screen(terminal);
    vterm_screen_enable_altscreen(screen, 1);
    vterm_screen_enable_reflow(screen, true);
    vterm_screen_reset(screen, 1);

    const char output[] = "\x1b[31mA\x1b[0m\xe7\x95\x8c\x1b[97;2;3m hint\x1b[22m!";
    assert(vterm_input_write(terminal, output, sizeof(output) - 1) == sizeof(output) - 1);
    vterm_screen_flush_damage(screen);

    VTermScreenCell cell = {0};
    assert(vterm_screen_get_cell(screen, (VTermPos){0, 0}, &cell));
    assert(cell.chars[0] == (uint32_t)'A');
    assert(cell.width == 1);
    assert(vterm_screen_get_cell(screen, (VTermPos){0, 1}, &cell));
    assert(cell.chars[0] == 0x754c);
    assert(cell.width == 2);

    VTermPos cursor = {0};
    vterm_state_get_cursorpos(vterm_obtain_state(terminal), &cursor);
    assert(cursor.row == 0);
    assert(cursor.col == 9);

    assert(vterm_screen_get_cell(screen, (VTermPos){0, 4}, &cell));
    assert(cell.chars[0] == (uint32_t)'h');
    assert(cell.attrs.faint == 1);
    assert(cell.attrs.italic == 1);
    assert(vterm_screen_get_cell(screen, (VTermPos){0, 8}, &cell));
    assert(cell.chars[0] == (uint32_t)'!');
    assert(cell.attrs.faint == 0);

    vterm_keyboard_key(terminal, VTERM_KEY_UP, VTERM_MOD_NONE);
    char input[16] = {0};
    const size_t input_length = vterm_output_read(terminal, input, sizeof(input));
    assert(input_length == 3);
    assert(memcmp(input, "\x1b[A", 3) == 0);

    vterm_free(terminal);
    return 0;
}
