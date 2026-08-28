mov ax, 0                   ; set stack pointer to 7C00
mov ss, ax
mov sp, 0x7C00

                            ; the only job of stage 1 boot sector is to
                            ; load the stage 2 sector and jump to it

mov ax, 0                   ; where to load sector 2 in ram 
mov es, ax
mov bx, 0x7E00              ; 31.5 kb right after stage 1

mov ah, 0x02                ; BIOS disk operation: read
mov al, 1                   ; read 1 sector
mov ch, 0                   ; cylinder 0
mov cl, 2                   ; sector 2
mov dh, 0                   ; head 0

int 0x13                    ; call BIOS read disk interrupt

jmp 0x0000:0x7E00           ; jump to newly loaded stage 2

times 510 - ($ - $$) db 0   ; $ - current address, $$ - start address
                            ; same as times 495 db 0
db 0x55, 0xAA               ; boot signature (0x55, 0xAA)