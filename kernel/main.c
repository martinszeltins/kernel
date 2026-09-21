void main(void) {
    short *vga = 0xB8000; // 736 KB (address of VGA text memory)
    *vga = 'K';

    for (;;);
}
