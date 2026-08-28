mov ax, 0xB800              ; VGA text memory segment
mov es, ax

mov byte [es:0], '2'        ; show "2" on screen

jmp $                       ; stay here forever

times 512 - ($ - $$) db 0   ; make Stage 2 exactly 512 bytes