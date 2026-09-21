void main() {
    char *vga_memory = (char *) 0xB8000;

    vga_memory[0] = 'K';
    vga_memory[1] = 0x07;

    for (;;);
}
