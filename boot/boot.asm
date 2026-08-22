mov ax, 0xB800              ; video memory address (B800 * 16 = 0xB8000)
mov es, ax                  ; ES cannot be loaded directly from an immediate value,
                            ; so use AX as temporary storage

mov byte [es:0], 'H'        ; write 'H' to video memory at address 0xB8000

jmp $                       ; jump to current address (infinite loop)

times 510 - ($ - $$) db 0   ; $ - current address, $$ - start address
                            ; same as times 495 db 0
db 0x55, 0xAA               ; boot signature (0x55, 0xAA)