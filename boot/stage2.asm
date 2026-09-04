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
    mov ax, 0x10                       ; allows us to access memory in 32-bit protected mode,
    mov ds, ax                         ; set data segment to 0x10 (gdt selector for 32-bit mode)
    mov ss, ax                         ; set stack segment to 0x10 (gdt selector for 32-bit mode)
    mov es, ax                         ; set extra segment to 0x10 (gdt selector for 32-bit mode)
    mov fs, ax                         ; set fs segment to 0x10 (gdt selector for 32-bit mode)
    mov gs, ax                         ; set gs segment to 0x10 (gdt selector for 32-bit mode)
    mov esp, 0x7C00                    ; set the stack pointer to 31 KB

                                       ; Set up Paging
                                       ; Create Level 4 (PML4) which will live at 96 KB (right after stage 2)
                                       ; It contains 512 entries. Each entry is 8 bytes (64 bits) (4 KB in total)

                                       ; Create PML4 Table  (96 KB - 100 KB)
    mov eax, 98304                     ; 96 KB - address of first PML4 entry
    mov ebx, 512                       ; number of entries to clear

    create_pml4:
        mov dword [eax], 0             ; clear first 32 bits of this entry
        mov dword [eax + 4], 0         ; clear second 32 bits of this entry

        add eax, 8                     ; point EAX at the next 8-byte entry

        sub ebx, 1                     ; one fewer entry left
        cmp ebx, 0                     ; are we finished?
        jne create_pml4                ; no → create the next entry

    mov byte [0xB8000], 'H'            ; just put H on the screen
    
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
