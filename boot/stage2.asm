org 0x7E00                             ; Stage 1 loads us at 0x7E00 (31.5 KB). Tell NASM our
                                       ; location so label addresses are calculated correctly.


; -----------------------------------------------------------------------------
; Get Memory Map From BIOS
; -----------------------------------------------------------------------------
;
; Lets use BIOS E820 routine to get a map of available and reserved memory
; so we can use it later to construct our memory bitmap.
;
; Location: 112 KB
;
mov ebx, 0                                  ; Rquesting entry #0, BIOS will update it
                                            ; after each request to point to next one.

mov di, 0                                   ; We will increment DI inside the loop for ES:DI

req_sysmap:
    mov eax, 0xE820                         ; BIOS E820 routine
    mov edx, 0x534D4150                     ; Magic word "SMAP" (requesting system map)
    mov ecx, 20                             ; Give us 20 bytes of info per entry
    mov bp, 7168                            ; Put results in 112 KB in RAM (ES * 16:DI)
    mov es, bp                              ; The fun of real mode addressing ;)
    
    int 0x15                                ; Call the BIOS interrupt

    add di, 20                              ; Increment RAM offset for next entry

    cmp ebx, 0                              ; Continue requesting entries until ebx is 0
    jne req_sysmap


   ; Add last entry to null terminate (all 0s)
    mov eax, 0
    null_terminate:
    mov byte [es:di], 0                     
    add di, 1
    add eax, 1
    cmp eax, 20
    jne null_terminate


; -----------------------------------------------------------------------------
; Enter Protected Mode
; -----------------------------------------------------------------------------

cli                                     ; Disable interrupts
lgdt [gdt_descriptor]                   ; Load GDT

; Turn on protected mode
mov eax, cr0                                 ; Copy the current CR0 value into EAX
or eax, 0b00000000000000000000000000000001   ; Turn on bit 0 (CR0.PE), leave all other bits unchanged
mov cr0, eax                                 ; Copy the modified value back into CR0

jmp 0x08:protected_mode                      ; Set CS = 0x08, GDT selector for entry #1 (code segment)


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

    ; -------------------------------------------------------------------------
    ; PD[0] —> PT link
    ; -------------------------------------------------------------------------

    mov dword [106496], 00000000000000011011000000000011b           ; lower 32 bits of PD[0] entry
    mov dword [106496 + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[6] - Stack (24 KB - 28 KB)
    ; -------------------------------------------------------------------------
    mov eax, 110592                                                        ; Address of PT[0] so we can calculate
                                                                           ; the address of each PTE easier instead of hardcoding it.

    mov dword [eax + (8 * 6)], 00000000000000000110000000000011b           ; lower 32 bits of PT[6] entry
    mov dword [eax + (8 * 6) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[7] - Stack, Stage1, Stage 2 (28 KB - 32 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 7)], 00000000000000000111000000000011b           ; lower 32 bits of PT[7] entry
    mov dword [eax + (8 * 7) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[8] - Stage 2 (32 KB - 36 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 8)], 00000000000000001000000000000011b           ; lower 32 bits of PT[8] entry
    mov dword [eax + (8 * 8) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[9] - Stage 2 (36 KB - 40 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 9)], 00000000000000001001000000000011b           ; lower 32 bits of PT[9] entry
    mov dword [eax + (8 * 9) + 4], 00000000000000000000000000000000b       ; upper 32 bits


    ; -------------------------------------------------------------------------
    ; PT[10] - Stage 2 (40 KB - 44 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 10)], 00000000000000001010000000000011b           ; lower 32 bits of PT[10] entry
    mov dword [eax + (8 * 10) + 4], 00000000000000000000000000000000b       ; upper 32 bits


    ; -------------------------------------------------------------------------
    ; PT[11] - Stage 2 (44 KB - 48 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 11)], 00000000000000001011000000000011b           ; lower 32 bits of PT[11] entry
    mov dword [eax + (8 * 11) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[12] - Stage 2 (48 KB - 52 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 12)], 00000000000000001100000000000011b           ; lower 32 bits of PT[12] entry
    mov dword [eax + (8 * 12) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[13] - Stage 2 (52 KB - 56 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 13)], 00000000000000001101000000000011b           ; lower 32 bits of PT[13] entry
    mov dword [eax + (8 * 13) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[14] - Stage 2 (56 KB - 60 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 14)], 00000000000000001110000000000011b           ; lower 32 bits of PT[14] entry
    mov dword [eax + (8 * 14) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[15] - Stage 2 (60 KB - 64 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 15)], 00000000000000001111000000000011b           ; lower 32 bits of PT[15] entry
    mov dword [eax + (8 * 15) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[16] - Stage 2 (64 KB - 68 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 16)], 00000000000000010000000000000011b           ; lower 32 bits of PT[16] entry
    mov dword [eax + (8 * 16) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[17] - Stage 2 (68 KB - 72 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 17)], 00000000000000010001000000000011b           ; lower 32 bits of PT[17] entry
    mov dword [eax + (8 * 17) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[18] - Stage 2 (72 KB - 76 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 18)], 00000000000000010010000000000011b           ; lower 32 bits of PT[18] entry
    mov dword [eax + (8 * 18) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[19] - Stage 2 (76 KB - 80 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 19)], 00000000000000010011000000000011b           ; lower 32 bits of PT[19] entry
    mov dword [eax + (8 * 19) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[20] - Stage 2 (80 KB - 84 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 20)], 00000000000000010100000000000011b           ; lower 32 bits of PT[20] entry
    mov dword [eax + (8 * 20) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[21] - Stage 2 (84 KB - 88 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 21)], 00000000000000010101000000000011b           ; lower 32 bits of PT[21] entry
    mov dword [eax + (8 * 21) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[22] - Stage 2 (88 KB - 92 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 22)], 00000000000000010110000000000011b           ; lower 32 bits of PT[22] entry
    mov dword [eax + (8 * 22) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[23] - Stage 2 (92 KB - 96 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 23)], 00000000000000010111000000000011b           ; lower 32 bits of PT[23] entry
    mov dword [eax + (8 * 23) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[24] - Page Tables, PML4 (96 KB - 100 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 24)], 00000000000000011000000000000011b           ; lower 32 bits of PT[24] entry
    mov dword [eax + (8 * 24) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[25] - Page Tables, PDPT (100 KB - 104 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 25)], 00000000000000011001000000000011b           ; lower 32 bits of PT[25] entry
    mov dword [eax + (8 * 25) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[26] - Page Tables, PD (104 KB - 108 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 26)], 00000000000000011010000000000011b           ; lower 32 bits of PT[26] entry
    mov dword [eax + (8 * 26) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[27] - Page Tables, PT (108 KB - 112 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 27)], 00000000000000011011000000000011b           ; lower 32 bits of PT[27] entry
    mov dword [eax + (8 * 27) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[184] - VGA Text Memory (736 KB - 740 KB)
    ; -------------------------------------------------------------------------

    mov dword [eax + (8 * 184)], 00000000000010111000000000000011b           ; lower 32 bits of PT[184] entry
    mov dword [eax + (8 * 184) + 4], 00000000000000000000000000000000b       ; upper 32 bits

    ; -------------------------------------------------------------------------
    ; PT[256-511] - Kernel (1 MB - 2 MB)
    ; -------------------------------------------------------------------------

    mov ebx, 256                                                              ; Map 256 pages (1 MB)
    mov ecx, 00000000000100000000000000000011b                                ; Starting position

    map_kernel:
        mov dword [eax + (8 * ebx)], ecx                                      ; lower 32 bits of PT entry
        mov dword [eax + (8 * ebx) + 4], 00000000000000000000000000000000b    ; upper 32 bits

        add ebx, 1     ; move to next page
        add ecx, 4096  ; ecx + 4KB (next page)

        cmp ebx, 512   ; have we already mapped 256 pages?

        jne map_kernel ; keep doing it until we map all 256 pages



    ; -----------------------------------------------------------------------
    ; Prepare and Enter 64-bit Long Mode
    ; -----------------------------------------------------------------------
    ;
    ; Now that our page tables are in place, we can flip a few CPU switches
    ; and finally enter 64-bit mode.
    ;
    ; 1. Set CR4.PAE bit. This transition from the old 32-bit 2-level mode
    ;    to the 64-bit 3-level paging mode.
    ;
    ; 2. Put the PML4 address in CR3 register to tell the CPU where our
    ;    page tables are located.
    ;
    ; 3. Set EFER.LME bit. This tells the CPU that when paging is turned on,
    ;    it should enter 64-bit long mode. Setting LME alone does NOT activate
    ;    long mode yet.
    ;
    ; 4. Add a new 64-bit code entry to the GDT. The entry must have L = 1
    ;    for 64-bit mode and D = 0 (not 32-bit mode). Entry #3 will have 0x18 as
    ;    its selector. We do not need another data entry. In 64-bit mode normal
    ;    data segmentation is mostly unused. We also need to update the GDT size
    ;    from 23 to 31.
    ;
    ; 5. Set the CR0.PG bit to turn paging on and active 64-bit long mode.
    ;
    ; 6. Far jump to GDT entry #3 (selector 0x18). This will set our 32-bit
    ;    CS register from 0x8 to 0x18 to use our new GDT entry.
    ;
    ; Note: We will be using a somewhat unconventional way of counting bits with
    ; the lowest bit being 1 and highest bit being 32.

    ; Turn on CR4.PAE (bit 6)
    mov eax, cr4
    or eax, 0b00000000000000000000000000100000
    mov cr4, eax

    ; Put PML4 address in CR3 (96 KB or 98304 bytes)
    ; Control registers must be loaded from general purpose regsiters.
    mov eax, 98304
    mov cr3, eax

    ; Turn on EFER.LME (bit 9)
    ; EFER is an MSR regsiter and must be accessed using special
    ; instructions: rdmsr and wrmsr
    mov ecx, 0xC0000080                            ; Select EFER
    rdmsr                                          ; Read EFER int EDX:EAX
    or eax, 0b00000000000000000000000100000000     ; turn on bit 9 (LME)
    wrmsr                                          ; Write EDX:EAX back to EFER

    ; Turn on Paging (CR0.PG) - bit 32
    mov eax, cr0
    or eax, 0b10000000000000000000000000000000
    mov cr0, eax

    jmp 0x18:long_mode

    ; -----------------------------------------------------------------------------
    ; 64-bit Long Mode
    ; -----------------------------------------------------------------------------

    [bits 64]
    
    long_mode:

        ; |________________________________________________________________________________________
        ; test reading sector 0 -> 95 KB
        ; Now know how to read from disk

        mov dx, 0x01F6       ; LBA highest bits / drive / flags
        mov al, 0b11100000
        out dx, al

        mov dx, 0x01F2        ; sector count
        mov al, 1             ; 1 sector
        out dx, al

        mov dx, 0x01F3       ; LBA low bits
        mov al, 0b00000000
        out dx, al

        mov dx, 0x01F4       ; LBA middle bits
        mov al, 0b00000000
        out dx, al

        mov dx, 0x01F5       ; LBA high bits
        mov al, 0b00000000
        out dx, al

        mov dx, 0x01F7       ; Command
        mov al, 0x20         ; READ command
        out dx, al

        check_status:
        mov dx, 0x01F7       ; Status (8 bits, so goes into AL)
        in al, dx

        test al, 0b10000000  ; Disk busy?
        jnz check_status
        
        test al, 0b00000001  ; Error? Lets just hang in that case.
        jnz check_status

        test al, 0b00001000  ; Data ready?
        jz check_status


        mov rbx, 97280       ; 95 KB - where to store data in RAM
        mov rcx, 0           ; how bytes we have read so far out of 512
        mov dx, 0x01F0

        disk_read:
        in ax, dx            ; 0x01F0 will hold 16 bits, put them in ax
        mov [rbx], ax        ; store that data in RAM
        add rbx, 2           ; move 2 bytes ahead
        add rcx, 2           ; increase bytes read

        cmp rcx, 512
        jne disk_read        ; not finished yet? read the next 2 bytes (16 bits)
        
        ; Test finished. We read 512 bytes from disk into RAM at 95 KB.
        ; DONE! We now know how to read from disk and talk to the disk directly!
        ; |________________________________________________________________________________________
        

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


                                        ; entry #3 - 64-bit code segment
    db 0xff, 0xff                       ; limit: 4 GB
    db 0, 0, 0                          ; base: 0
    db 10011010b                        ; code, readable, ring 0, present
    db 10101111b                        ; 64-bit: L=1, D=0, 4 KB granularity
    db 0                                ; base: 0


; -----------------------------------------------------------------------------
; GDT Descriptor
; -----------------------------------------------------------------------------
;
; A simple structure telling the CPU the address and size of the GDT table so it
; can load it into memory.

gdt_descriptor:
    dw 31                               ; GDT size (technically GDT limit 32 bytes - 1)
    dd gdt                              ; GDT address


; -----------------------------------------------------------------------------
; Stage 2 Padding
; -----------------------------------------------------------------------------

times 65024 - ($ - $$) db 0             ; make Stage 2 exactly 65024 bytes (63.5 KB)
