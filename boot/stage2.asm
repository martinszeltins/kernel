org 0x7E00                             ; Stage 2 loads us in RAM at 7E00 (31.5 KB)

cli                                    ; disable interrupts
lgdt [gdt_descriptor]                  ; load gdt

                                       ; turn on protected mode
mov eax, cr0                           ; copy the current CR0 value into EAX
or eax, 0x00000001                     ; turn on bit 0 (CR0.PE), leave all other bits unchanged
mov cr0, eax                           ; copy the modified value back into CR0

jmp 0x08:protected_mode                ; set CS = 0x08

[bits 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov byte [0xB8000], 'H'
    
    jmp $                              ; stay here forever for now

gdt:
    db 0, 0, 0, 0, 0, 0, 0, 0          ; entry #0 - null

                                       ; entry #1 - code segment (FF FF 00 00 00 9A CF 00)
    db 0xff, 0xff                      ; limit: 4 GB
    db 0, 0, 0                         ; base: 0
    db 10011010b                       ; permissions: code, readable, ring 0, present
    db 11001111b                       ; 32bit, 4 KB granularity, upper limit = F
    db 0                               ; base: 0

                                       ; entry #2 - data segment (FF FF 00 00 00 92 CF 00)
    db 0xff, 0xff                      ; limit: 4 GB
    db 0, 0, 0                         ; base: 0
    db 10010010b                       ; permissions: data, writable, ring 0, present
    db 11001111b                       ; 32bit, 4 KB granularity, upper limit = F
    db 0                               ; base: 0

gdt_descriptor:
    dw 23                              ; gdt size
    dd gdt                             ; gdt address

times 65024 - ($ - $$) db 0            ; make Stage 2 exactly 65024 bytes (63.5 KB)
