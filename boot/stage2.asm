org 0x7E00                             ; Stage 1 loads us at 0x7E00 (31.5 KB). Tell NASM our
                                       ; location so label addresses are calculated correctly.

; -----------------------------------------------------------------------------
; Enter Protected Mode
; -----------------------------------------------------------------------------

cli                                     ; Disable interrupts
lgdt [gdt_descriptor]                   ; Load GDT

; Turn on protected mode
mov eax, cr0                            ; Copy the current CR0 value into EAX
or eax, 0x00000001                      ; Turn on bit 0 (CR0.PE), leave all other bits unchanged
mov cr0, eax                            ; Copy the modified value back into CR0

jmp 0x08:protected_mode                 ; Set CS = 0x08, GDT selector for entry #1 (code segment)


; -----------------------------------------------------------------------------
; 32-bit Protected Mode
; -----------------------------------------------------------------------------

[bits 32]

protected_mode:
    mov ax, 0x10                        ; 0x10 selects GDT entry #2 — our 32-bit data segment

    mov ds, ax                          ; Use the data segment for normal memory access
    mov ss, ax                          ; Use the data segment for the stack
    mov es, ax                          ; Use the data segment for ES
    mov fs, ax                          ; Use the data segment for FS
    mov gs, ax                          ; Use the data segment for GS

    mov esp, 0x7C00                     ; Set the 32-bit stack pointer to 31 KB


    ; -------------------------------------------------------------------------
    ; Set up Paging
    ; -------------------------------------------------------------------------
    ;
    ; Paging is required for 64-bit long mode.
    ; Create Level 4 (PML4) table which will live at 96 KB (right after stage 2)
    ; It contains 512 entries. Each entry is 8 bytes (64 bits) (4 KB in total)
    ;
    ; For now, all we need to do is clear the whole table.
    ; And since bit 0 of each entry is the Present bit, we can just write 0s to the whole table.
    ; Later, we will take the first entry and point it to the Level 3 (PDPT) table.
    
    ; -------------------------------------------------------------------------
    ; Create PML4 Table (Level 4)  (96 KB - 100 KB)
    ; -------------------------------------------------------------------------

    mov eax, 98304                      ; 98304 bytes (96 KB) - address of the beginning of the PML4 table
                                        ; 96 KB is right after Stage 2
    mov ebx, 512                        ; Number of entries to clear

    create_pml4:
        mov dword [eax], 0              ; Clear first 32 bits of this entry
        mov dword [eax + 4], 0          ; Clear second 32 bits of this entry

        add eax, 8                      ; Point EAX at the next 8-byte entry

        sub ebx, 1                      ; One fewer entry left
        cmp ebx, 0                      ; Are we finished?
        jne create_pml4                 ; No → create the next entry

    ; -------------------------------------------------------------------------
    ; Create PDPT Table (Level 3) (100 KB - 104 KB)
    ; -------------------------------------------------------------------------

    mov eax, 102400                     ; 102400 bytes (100 KB) - address of the beginning of the PDPT table
                                        ; 100 KB is right after PML4
    mov ebx, 512                        ; Number of entries to clear

    create_pdpt:
        mov dword [eax], 0              ; Clear first 32 bits of this entry
        mov dword [eax + 4], 0          ; Clear second 32 bits of this entry

        add eax, 8                      ; Point EAX at the next 8-byte entry

        sub ebx, 1                      ; One fewer entry left
        cmp ebx, 0                      ; Are we finished?
        jne create_pdpt                 ; No → create the next entry

    ; -------------------------------------------------------------------------
    ; Create PD Table (Level 2) (104 KB - 108 KB)
    ; -------------------------------------------------------------------------

    mov eax, 106496                     ; 106496 bytes (104 KB) - address of the beginning of the PD table
                                        ; 104 KB is right after PDPT
    mov ebx, 512                        ; Number of entries to clear

    create_pd:
        mov dword [eax], 0              ; Clear first 32 bits of this entry
        mov dword [eax + 4], 0          ; Clear second 32 bits of this entry

        add eax, 8                      ; Point EAX at the next 8-byte entry

        sub ebx, 1                      ; One fewer entry left
        cmp ebx, 0                      ; Are we finished?
        jne create_pd                   ; No → create the next entry

    ; -------------------------------------------------------------------------
    ; Create PT Table (Level 1) (108 KB - 112 KB)
    ; -------------------------------------------------------------------------

    mov eax, 110592                     ; 110592 bytes (108 KB) - address of the beginning of the PT table
                                        ; 108 KB is right after PD
    mov ebx, 512                        ; Number of entries to clear

    create_pt:
        mov dword [eax], 0              ; Clear first 32 bits of this entry
        mov dword [eax + 4], 0          ; Clear second 32 bits of this entry

        add eax, 8                      ; Point EAX at the next 8-byte entry

        sub ebx, 1                      ; One fewer entry left
        cmp ebx, 0                      ; Are we finished?
        jne create_pt                   ; No → create the next entry


    ; -------------------------------------------------------------------------
    ; PML4[0] —> PDPT link
    ; -------------------------------------------------------------------------
    ;
    ; For our 2 stack pages mapping, we will need to create the links:
    ; PML4[0] —> PDPT[0] —> PD[0] —> PT[6,7]
    ;
    ; Level 4 Entry (PML4E)
    ; ┌──┬────────────┬──────────────────────────────┬───┬─┬─┬─┬─┬─┬─┐
    ; │63│ 62 .ign. 52│        51 ..addr.. 12        │...│A│C│W│U│R│P│
    ; └──┴────────────┴──────────────────────────────┴───┴─┴─┴─┴─┴─┴─┘

                                                                   ; 00000000000000011001 (upper address bits of PDPT address)
                                                                   ; CPU knows the lower 12 address bits are 0 because the table is 4 KB aligned
    mov dword [98304], 00000000000000011001000000000011b           ; lower 32 bits of PML4[0] entry (since we are in 32-bit mode)
    mov dword [98304 + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PDPT[0] —> PD link
    ; -------------------------------------------------------------------------

    mov dword [102400], 00000000000000011010000000000011b           ; lower 32 bits of PDPT[0] entry
    mov dword [102400 + 4], 00000000000000000000000000000000b       ; upper 32 bits


    mov byte [0xB8000], 'H'             ; Just put H on the screen
    jmp $                               ; And stay here forever for now


; -----------------------------------------------------------------------------
; GDT (Global Descriptor Table)
; -----------------------------------------------------------------------------
;
; Required for entering the protected mode. In protected mode, the CPU uses a
; different memory addressing logic. Instead of using the segment:offset logic,
; it uses the segment as a selector in the GDT table. This simplifies memory
; access quite a bit.

gdt:
    db 0, 0, 0, 0, 0, 0, 0, 0           ; entry #0 - null

                                        ; entry #1 - code segment (FF FF 00 00 00 9A CF 00)
    db 0xff, 0xff                       ; limit: 4 GB
    db 0, 0, 0                          ; base: 0
    db 10011010b                        ; permissions: code, readable, ring 0, present
    db 11001111b                        ; 32bit, 4 KB granularity, upper limit = F
    db 0                                ; base: 0

                                        ; entry #2 - data segment (FF FF 00 00 00 92 CF 00)
    db 0xff, 0xff                       ; limit: 4 GB
    db 0, 0, 0                          ; base: 0
    db 10010010b                        ; permissions: data, writable, ring 0, present
    db 11001111b                        ; 32bit, 4 KB granularity, upper limit = F
    db 0                                ; base: 0


; -----------------------------------------------------------------------------
; GDT Descriptor
; -----------------------------------------------------------------------------
;
; A simple structure telling the CPU the address and size of the GDT table so it
; can load it into memory.

gdt_descriptor:
    dw 23                               ; GDT size (technically GDT limit 24 bytes - 1)
    dd gdt                              ; GDT address


; -----------------------------------------------------------------------------
; Stage 2 Padding
; -----------------------------------------------------------------------------

times 65024 - ($ - $$) db 0             ; make Stage 2 exactly 65024 bytes (63.5 KB)
