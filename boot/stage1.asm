org 0x7C00                     ; BIOS loads us in RAM at 7C00 (31 KB)
                               ; inform assembler about our location so
                               ; it can calcuate label addresses etc.

mov ax, 0                      ; set the stack pointer to 7C00
mov ss, ax                     ; it will grow upwards towards 0
mov sp, 0x7C00


                               ; the only job of stage 1 boot sector is to
                               ; load the stage 2 sector and jump to it.

                               ; ask BIOS to read 127 blocks/sectors from
                               ; disk starting from sector 2 into memory
                               ; address at 31.5 KB (after stage 1)
                               ; we have decided that our stage 2 will be
                               ; 127 sectors (64 KB) big.


mov ax, 0                      ; BIOS expects to find the address of the packet
mov ds, ax                     ; at DS:SI
mov si, disk_read_packet
                               ; ┌──────┐  ┌──────────────────┐  ┌──────┐
                               ; │  DS  │  │          SI      │  │  AH  │
                               ; │  0   │  │ disk_packet addr │  │ 0x42 │
                               ; └──────┘  └──────────────────┘  └──────┘

mov ah, 0x42                   ; request BIOS extended disk read routine
int 0x13                       ; call BIOS read disk interrupt

jmp 0x0000:0x7E00              ; jump to newly loaded stage 2 at 31.5 KB


disk_read_packet:                            
    db 0x10                    ; packet size (16 bytes)
    db 0                       ; reserved
    dw 127                     ; read 127 sectors
    dw 0                       ; offset    (07E0:0000) = 0x07E0 × 16 + 0 = 
    dw 0x07E0                  ; segment   31.5 KB    (RAM location of the read data)
    dq 1                       ; start sector

times 510 - ($ - $$) db 0      ; $ - current address, $$ - start address
                               ; same as times 495 db 0

db 0x55, 0xAA                  ; boot signature (0x55, 0xAA)