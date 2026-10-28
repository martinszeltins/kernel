/*
 * VGA Text Mode
 *
 * VGA text memory begins at address 0xB8000 (736 KB).
 *
 * The screen has 80 columns and 25 rows.
 * That's 80 * 25 = 2000 character positions.
 *
 * Each character occupies 2 bytes in VGA memory:
 *
 * Byte 1: The character itself (e.g. 'K')
 * Byte 2: The color (0x07 = light gray on black)
 *
 * Address       Value       Meaning
 * ------------------------------------------
 * 0xB8000       'H'         First character
 * 0xB8001       0x07        First character color
 * 0xB8002       'e'         Second character
 * 0xB8003       0x07        Second character color
 * 0xB8004       'l'         Third character
 * 0xB8005       0x07        Third character color
 */

int screen_width = 80;
int screen_height = 25;

int cursor_x = 0;
int cursor_y = 0;

void clear_screen(void) {
    char *vga_memory = (char *)0xB8000;

    for (int i = 0; i < screen_width * screen_height; i++) {
        vga_memory[i * 2] = ' ';
        vga_memory[i * 2 + 1] = 0x07;
    }

    cursor_x = 0;
    cursor_y = 0;
}

void print(const char *text) {
    char *vga_memory = (char *)0xB8000;
    
    for (int i = 0; text[i] != '\0'; i++) {
        if (text[i] == '\n') {
            // If we encounter a newline (\n), move cursor down to get a new line.
            cursor_x = 0;
            cursor_y++;
        } else {
            int vga_pos = (cursor_y * screen_width + cursor_x) * 2;

            vga_memory[vga_pos] = text[i];
            vga_memory[vga_pos + 1] = 0x07;

            cursor_x++;
        }

        // Reached the right edge? Move to the next row.
        if (cursor_x >= screen_width) {
            cursor_x = 0;
            cursor_y++;
        }

        // Reached the bottom? Start again at the top 乁(ツ)ㄏ
        if (cursor_y >= screen_height) {
            cursor_y = 0;
        }
    }

    // Move cursor to the next line after each print() call
    cursor_x = 0;
    cursor_y++;
}
