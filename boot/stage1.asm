org 0x7C00                     ; BIOS loads us at 0x7C00 (31 KB). Tell NASM our
                               ; location so label addresses are calculated correctly.


; -----------------------------------------------------------------------------
; Stack
; -----------------------------------------------------------------------------
;
; Se the Stack pointer to 0x7C00. The stack will grow upwards toward 0.
; 0x7C00 happens to also be the address of Stage 1. Stage 1 grows downwards,
; whereas the stack grows upwards.

mov ax, 0
mov ss, ax
mov sp, 0x7C00


; -----------------------------------------------------------------------------
; Load Stage 2
; -----------------------------------------------------------------------------
;
; The only job of Stage 1 is to load Stage 2 into RAM and jump to it.
;
; Stage 2 lives on disk from sector 2 to sector 128. It is 63.5 KB and
; we want to load it into memory at 31.5 KB - 95 KB.

mov ax, 0                                ; BIOS expects the packet address in DS:SI
mov ds, ax
mov si, disk_read_packet
mov ah, 0x42                             ; 0x42 — BIOS extended disk read function

;
; ┌──────┐  ┌──────────────────┐  ┌──────┐
; │  DS  │  │        SI        │  │  AH  │
; │  0   │  │ packet address   │  │ 0x42 │
; └──────┘  └──────────────────┘  └──────┘

int 0x13                                 ; Call BIOS disk interrupt

jmp 0x0000:0x7E00                        ; Jump to newly loaded stage 2 at 31.5 KB


; -----------------------------------------------------------------------------
; BIOS Disk Read Packet
; -----------------------------------------------------------------------------

disk_read_packet:
    db 0x10                             ; Packet size: 16 bytes (0x10)
    db 0                                ; Reserved
    dw 127                              ; Number of sectors to read
    dw 0                                ; Destination offset:  0000 (07E0:0000) = 0x07E0 × 16 + 0
    dw 0x07E0                           ; Destination segment: 0x7E00 = 31.5 KB  (After Stage 1)
    dq 1                                ; Starting disk sector (1)


; -----------------------------------------------------------------------------
; Boot Signature
; -----------------------------------------------------------------------------
;
; This is how BIOS recognizes a bootable disk.
; The last two bytes must be 0x55 and 0xAA (alternating 1s and 0s)
; 01010101 10101010

times 510 - ($ - $$) db 0               ; $ - current address, $$ - start address
db 0x55, 0xAA                           ; BIOS boot signature (0x55, 0xAA)
