#### Level 4 (PML4) = Page Map Level 4

#### Level 3 (PDPT) = Page Directory Pointer Table

#### Level 2 (PD)   = Page Directory

#### Level 1 (PT)   = Page Table

## A Level 1 entry (PTE)

A Level 1 entry is exactly:

```text
64 bits = 8 bytes
```

Unlike the higher-level entries, a Level 1 entry does **not** point to another paging table.

It points from:

```text
Level 1 (PT)
     ↓
physical 4 KB RAM frame
```

For example:

```text
PT[6]
  ↓
physical 24 KB – 28 KB
```

One Level 1 entry maps exactly:

```text
4 KB of virtual memory
        ↓
4 KB of physical memory
```

### Bits 63–48

```text
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| bit  | 63 | 62 | 61 | 60 | 59 | 58 | 57 | 56 | 55 | 54 | 53 | 52 | 51 | 50 | 49 | 48 |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| name | NX | PK | PK | PK | PK | IG | IG | IG | IG | IG | IG | IG |ADR |ADR |ADR |ADR |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
```

### Bits 47–32

```text
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| bit  | 47 | 46 | 45 | 44 | 43 | 42 | 41 | 40 | 39 | 38 | 37 | 36 | 35 | 34 | 33 | 32 |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| name |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
```

### Bits 31–16

```text
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| bit  | 31 | 30 | 29 | 28 | 27 | 26 | 25 | 24 | 23 | 22 | 21 | 20 | 19 | 18 | 17 | 16 |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| name |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
```

### Bits 15–0

```text
+------+----+----+----+----+----+----+----+----+-----+-----+---+---+---+-----+-----+---+
| bit  | 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7  |  6  | 5 | 4 | 3 |  2  |  1  | 0 |
+------+----+----+----+----+----+----+----+----+-----+-----+---+---+---+-----+-----+---+
| name |ADR |ADR |ADR |ADR | R* | IG | IG | G  | PAT |  D  | A |PCD|PWT| U/S | R/W | P |
+------+----+----+----+----+----+----+----+----+-----+-----+---+---+---+-----+-----+---+
```

## Summary

* **NX:** No-execute bit. If set, prevents instruction execution from this 4 KB page.
* **PK:** Protection Key. Provides additional access-control information when protection keys are enabled; otherwise ignored.
* **IG:** Ignored bit. Its value is not used by the processor for normal address translation here.
* **ADDR:** Physical address of the 4 KB physical RAM frame mapped by this entry.
* **R*:** Restart bit for HLAT paging; ignored for our ordinary paging setup.
* **G:** Global bit. Can tell the CPU to keep this translation across certain address-space changes when global pages are enabled.
* **PAT:** Page Attribute Table bit. Helps determine the memory caching/type behavior for this physical page.
* **D:** Dirty bit. Set by the processor when software writes to this 4 KB page.
* **A:** Accessed bit. Set by the processor when this 4 KB page is accessed.
* **PCD:** Page-level cache disable. Helps determine the caching behavior used for this 4 KB page.
* **PWT:** Page-level write-through. Helps determine the caching behavior used for this 4 KB page.
* **U/S:** User/Supervisor bit. Determines whether user-mode access may be allowed to this 4 KB page.
* **R/W:** Read/Write bit. Determines whether writes may be allowed to this 4 KB page.
* **P:** Present bit. If set, this entry contains a valid mapping to a physical 4 KB page.

## Explanation

**NX — No Execute / Execute Disable**

Bit 63.

```text
NX = 0   instruction execution is allowed from this page
NX = 1   instruction execution is prohibited from this page
```

Unlike a Level 4 entry, which affects an entire branch underneath it, a Level 1 entry controls the final 4 KB page itself.

NX has this meaning when the CPU's NX feature is enabled through `EFER.NXE`.

Otherwise, this bit is reserved and must remain:

```text
NX = 0
```

For our initial bootloader mappings:

```text
NX = 0
```

---

**PK — Protection Key**

Bits 62–59.

These four bits form a protection-key number:

```text
0000 – 1111
```

which gives 16 possible protection keys.

Modern x86 CPUs can use protection keys as an additional way of controlling access to pages.

They are used when protection-key features such as `CR4.PKE` or `CR4.PKS` are enabled.

We are not using protection keys.

For our bootloader:

```text
PK = 0000
```

When the relevant protection-key feature is disabled, these bits do not control access to our page.

---

**IG — Ignored**

The processor does not use these bits for ordinary address translation here.

For our simple bootloader, we write:

```text
IG = 0
```

This keeps the entry simple and predictable.

"Ignored" is different from "reserved":

```text
Ignored  = CPU does not use the value here.
Reserved = architecture requires us to leave it at the required value, normally 0.
```

---

**ADDR — Physical address of the 4 KB RAM frame**

This is the most important difference between a Level 1 entry and the higher-level entries.

Higher levels point to another paging table:

```text
PML4E → PDPT
PDPTE → PD
PDE   → PT
```

But a Level 1 entry is the end of the tree:

```text
PTE → physical RAM
```

The address field begins at bit 12.

It tells the CPU:

```text
Where in physical RAM is the 4 KB frame for this virtual page?
```

For example, for our first stack mapping:

```text
PT[6] → physical 24 KB
```

24 KB is:

```text
24 KB = 24576 bytes
```

and:

```text
24 KB / 4 KB = 6
```

So the physical frame number is:

```text
6
```

In binary:

```text
110
```

The complete physical frame address is therefore:

```text
110 | 000000000000
      ^^^^^^^^^^^^
      12 zeros
```

Those lowest 12 address bits are always zero because every 4 KB physical frame begins on a 4 KB boundary.

Therefore those bottom bit positions can instead be used for flags.

The processor knows that the lowest 12 bits of the physical frame's base address are zero.

Important: a particular CPU may implement fewer than 52 physical-address bits. Unsupported upper address bits are reserved and must remain `0`.

---

**R* — Restart / ignored for us**

Bit 11.

Intel gives this bit a special `Restart` meaning when using HLAT paging.

We are not using HLAT.

For our ordinary paging setup, this bit is ignored.

We write:

```text
R = 0
```

---

**G — Global**

Bit 8.

The Global bit can mark this page translation as global when global-page support is enabled with:

```text
CR4.PGE = 1
```

A global translation can remain cached in the CPU's translation cache across certain address-space switches instead of being discarded every time `CR3` changes.

This is useful later for kernel pages that are shared by every process.

We are not using global pages yet.

For our bootloader:

```text
G = 0
```

---

**PAT — Page Attribute Table**

Bit 7.

PAT helps determine what kind of memory-caching behavior should be used for this 4 KB page.

For ordinary RAM, we do not need to change it.

For our bootloader:

```text
PAT = 0
```

PAT becomes more interesting later for special kinds of memory, such as memory-mapped hardware.

---

**D — Dirty**

Bit 6.

The processor sets this bit when software writes to the 4 KB page.

Initially we write:

```text
D = 0
```

If the page is later written to, the processor may change it to:

```text
D = 1
```

So it tells the operating system:

```text
"This physical page has been written to."
```

This becomes useful later for things such as memory management and deciding whether modified memory must be saved somewhere.

For our initial entry:

```text
D = 0
```

---

**A — Accessed**

Bit 5.

The processor sets this bit when the 4 KB page is accessed.

Initially we write:

```text
A = 0
```

After the CPU uses the page, hardware may change it to:

```text
A = 1
```

It therefore tells the operating system:

```text
"This page has been used."
```

For our initial entry:

```text
A = 0
```

---

**PCD — Page-level Cache Disable**

Bit 4.

This participates in determining the caching behavior used when accessing this 4 KB page.

```text
PCD = 0   normal caching behavior
PCD = 1   cache-disable setting
```

For ordinary RAM:

```text
PCD = 0
```

---

**PWT — Page-level Write-Through**

Bit 3.

This also participates in determining the caching behavior used for this 4 KB page.

```text
PWT = 0   normal write-back-style behavior
PWT = 1   write-through setting
```

For our ordinary RAM pages:

```text
PWT = 0
```

---

**U/S — User / Supervisor**

Bit 2.

This controls whether user-mode code may access this 4 KB page.

```text
U/S = 0   supervisor/kernel access only
U/S = 1   user-mode access may be allowed
```

For our bootloader/kernel:

```text
U/S = 0
```

We do not have user processes yet.

---

**R/W — Read / Write**

Bit 1.

This controls whether writes may be allowed to this 4 KB page.

```text
R/W = 0   writes restricted
R/W = 1   writes allowed
```

Our stack obviously needs to be writable because `push`, `call`, local variables, and other stack operations write data into it.

Therefore:

```text
R/W = 1
```

---

**P — Present**

Bit 0.

This tells the processor whether this Level 1 entry contains a valid mapping.

```text
P = 0   this virtual page has no valid physical mapping here
P = 1   this virtual page maps to a physical 4 KB frame
```

For our stack page:

```text
P = 1
```

because we want this virtual page to be usable.

---

## Our PT[6] values

We want:

```text
virtual 24 KB → physical 24 KB
```

Because each page is 4 KB:

```text
24 KB / 4 KB = 6
```

therefore:

```text
PT[6] → physical 24 KB
```

For this entry:

```text
NX   = 0
PK   = 0000
IG   = 0
ADR  = physical 24 KB
R*   = 0
G    = 0
PAT  = 0
D    = 0
A    = 0
PCD  = 0
PWT  = 0
U/S  = 0
R/W  = 1
P    = 1
```

The important bottom nine bits are:

```text
+------+---+-----+---+---+---+-----+-----+-----+-----+---+
| bit  | 8 |  7  | 6 | 5 | 4 |  3  |  2  |  1  |  0  |
+------+---+-----+---+---+---+-----+-----+-----+-----+---+
| name | G | PAT | D | A |PCD| PWT | U/S | R/W |  P  |
+------+---+-----+---+---+---+-----+-----+-----+-----+---+
| val  | 0 |  0  | 0 | 0 | 0 |  0  |  0  |  1  |  1  |
+------+---+-----+---+---+---+-----+-----+-----+-----+---+
```

Therefore the bottom bits are:

```text
000000011
       ^^
       ||
       |└── Present = 1
       └── Read/Write = 1
```

The physical address is:

```text
24 KB = 24576 bytes
```

In binary:

```text
00000000000000000110000000000000
```

After adding the `Present` and `Read/Write` flags:

```text
00000000000000000110000000000011
```

So our complete 64-bit `PT[6]` entry is:

```text
upper 32 bits:
00000000000000000000000000000000

lower 32 bits:
00000000000000000110000000000011
```

This means:

```text
PT[6]
  ↓
physical frame beginning at 24 KB

Present  = yes
Writable = yes
User     = no
Execute  = yes
```

So virtual addresses:

```text
24 KB – just below 28 KB
```

map to physical addresses:

```text
24 KB – just below 28 KB
```

This is an identity mapping:

```text
virtual address = physical address
```

Everything else that we do not currently need is deliberately initialized to `0`.
