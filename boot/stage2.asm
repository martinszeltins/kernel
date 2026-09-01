org 0x7E00                    ; Stage 2 loads us in RAM at 7E00 (31.5 KB)

mov ax, 0xB800                ; VGA text memory segment
mov es, ax

mov byte [es:0], '2'          ; show "2" on screen

jmp $                         ; stay here forever

times 65024 - ($ - $$) db 0   ; make Stage 2 exactly 65024 bytes (63.5 KB)