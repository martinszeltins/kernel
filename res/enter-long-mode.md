; -----------------------------------------------------------------------------
; Prepare and Enter 64-bit Long Mode
; -----------------------------------------------------------------------------
;
; Order matters.
;
; 1. CR4.PAE
;    Enable PAE (Physical Address Extension).
;
;    Without PAE, old 32-bit paging uses:
;        PD -> PT                         (2 levels, 32-bit entries)
;
;    With PAE enabled, paging uses:
;        PDPT -> PD -> PT                 (3 levels, 64-bit entries)
;
;
; 2. CR3
;    Tell the CPU where our paging tree starts.
;
;    We are preparing for 64-bit long mode, so CR3 will contain the physical
;    address of our Level 4 (PML4), which lives at 96 KB.
;
;
; 3. EFER.LME
;    Set LME (Long Mode Enable).
;
;    This tells the CPU that when paging is turned on, it should enter
;    64-bit long mode and use:
;
;        PML4 -> PDPT -> PD -> PT         (4 levels, 64-bit entries)
;
;    Setting LME alone does NOT activate long mode yet.
;
;
; 4. Add a NEW 64-bit code entry to the GDT
;
;    Our GDT currently contains:
;
;        entry #0 = NULL
;        entry #1 = 32-bit code
;        entry #2 = data
;
;    Add:
;
;        entry #3 = 64-bit code
;
;    The new 64-bit code descriptor must have:
;
;        L = 1     ; 64-bit code
;        D = 0     ; not 32-bit code
;
;    Entry #3 has selector 0x18.
;
;    We do NOT need another data entry. In 64-bit mode normal data
;    segmentation is mostly unused, so our existing data entry is sufficient.
;
;    Since the GDT grows from 3 entries (24 bytes) to 4 entries (32 bytes),
;    change the GDT limit from 23 to 31.
;
;
; 5. CR0.PG
;    Turn paging ON.
;
;    At this point:
;
;        CR4.PAE  = 1
;        CR3      = address of our PML4
;        EFER.LME = 1
;
;    Therefore turning CR0.PG on activates both:
;
;        paging
;        +
;        the 64-bit long-mode environment
;
;
; 6. Far jump to GDT entry #3 (selector 0x18)
;
;    This changes CS from our 32-bit code descriptor:
;
;        CS = 0x08 -> GDT entry #1 -> L=0, D=1
;
;    to our new 64-bit code descriptor:
;
;        CS = 0x18 -> GDT entry #3 -> L=1, D=0
;
;    The CPU now begins executing actual 64-bit code.
;
;
; Summary:
;
;    CR4.PAE = 1
;        ↓
;    2-level 32-bit paging format -> 3-level PAE paging format
;    (64-bit paging entries)
;        ↓
;    CR3 = PML4 address at 96 KB
;        ↓
;    EFER.LME = 1
;        ↓
;    prepare 4-level 64-bit long-mode paging:
;    PML4 -> PDPT -> PD -> PT
;        ↓
;    add GDT entry #3 = 64-bit code (L=1, D=0)
;        ↓
;    CR0.PG = 1
;        ↓
;    paging + 64-bit long-mode environment become active
;        ↓
;    far jump to selector 0x18
;        ↓
;    CS uses the 64-bit code descriptor
;        ↓
;    actual 64-bit code execution
; -----------------------------------------------------------------------------


1. CR4.PAE = 1

2. CR3 = physical address of PML4
          = 96 KB

3. EFER.LME = 1

4. Add GDT entry #3:
      64-bit CODE
      L = 1
      D = 0

   Update GDT limit:
      23 → 31

5. CR0.PG = 1

6. Far jump:
      CS = 0x18
      ↓
      GDT entry #3
      ↓
      L = 1
      ↓
      execute 64-bit code

7. [bits 64]
   64_bit_code:
