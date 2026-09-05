#### Level 4 (PML4) = Page Map Level 4
#### Level 3 (PDPT) = Page Directory Pointer Table
#### Level 2 (PD)   = Page Directory
#### Level 1 (PT)   = Page Table

## A Level 4 entry (PML4E)

A Level 4 entry is exactly:

```text
64 bits = 8 bytes
```

It points from:

```text
Level 4 (PML4)
       ↓
Level 3 (PDPT)
```

### Bits 63–48

```text
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| bit  | 63 | 62 | 61 | 60 | 59 | 58 | 57 | 56 | 55 | 54 | 53 | 52 | 51 | 50 | 49 | 48 |
+------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| name | NX | IG | IG | IG | IG | IG | IG | IG | IG | IG | IG | IG |ADR |ADR |ADR |ADR |
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
+------+----+----+----+----+-----+----+----+----+----+----+----+-----+-----+-----+-----+---+
| bit  | 15 | 14 | 13 | 12 | 11  | 10 |  9 |  8 |  7 |  6 |  5 |  4  |  3  |  2  |  1  | 0 |
+------+----+----+----+----+-----+----+----+----+----+----+----+-----+-----+-----+-----+---+
| name |ADR |ADR |ADR |ADR | R*  | IG | IG | IG | RS | IG | A  | PCD | PWT | U/S | R/W | P |
+------+----+----+----+----+-----+----+----+----+----+----+----+-----+-----+-----+-----+---+
```

## Summary
- **NX:** No-execute bit. If set, prevents instruction execution through this entire Level 4 branch.
- **IG:** Ignored bit. Its value is not used by the processor for normal address translation here.
- **ADDR:** Physical address of the next-level table, which is the Level 3 (PDPT).
- **RS:** Reserved bit. Must be set to 0.
- **A:** Accessed bit. Set by the processor when this Level 4 entry is used during address translation.
- **PCD:** Page-level cache disable. Controls caching behavior when accessing the referenced Level 3 (PDPT) table.
- **PWT:** Page-level write-through. Controls write-through caching behavior for accesses to the referenced Level 3 (PDPT) table.
- **U/S:** User/Supervisor bit. Determines whether user-mode access may pass through this Level 4 branch.
- **R/W:** Read/Write bit. Determines whether writes may be allowed through this Level 4 branch.
- **P:** Present bit. If set, this entry contains a valid reference to a Level 3 (PDPT) table.

## Explanation

**NX — No Execute / Execute Disable**

Bit 63.

```text
NX = 0   instruction execution is allowed through this branch
NX = 1   instruction execution is prohibited through this branch
```

For a Level 4 entry, this affects the entire virtual-address region underneath that entry, not merely one 4 KB page.

NX has this meaning when the CPU's NX feature is enabled through `EFER.NXE`. Otherwise this bit is reserved and must remain `0`.

For our initial bootloader:

```text
NX = 0
```

---

**IG — Ignored**

The processor does not use this bit for ordinary address translation in this type of entry.

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

**ADR — Physical address of the next Level 3 (PDPT) table**

The address field occupies the physical-address bits beginning at bit 12.

It tells the CPU:

```text
Where in physical RAM is the Level 3 (PDPT)?
```

For our setup:

```text
Level 3 (PDPT) starts at 100 KB.
```

Because every paging table is 4 KB aligned, the lowest 12 address bits would always be zero:

```text
[address bits] 000000000000
               ^^^^^^^^^^^^
               12 zeros
```

Therefore those lowest 12 bit positions do not need to store address information.

The processor knows that the physical address of the next table has 12 zero bits at the bottom.

Important: a particular CPU may implement fewer than 52 physical-address bits. Any unsupported upper address bits are reserved and must remain `0`.

---

**R* — Restart / ignored for us**

Bit 11.

Intel gives this bit a special `Restart` meaning when using the newer HLAT paging feature.

We are not using HLAT.

For our ordinary paging setup, this bit is ignored.

We write:

```text
R = 0
```

---

**RS — Reserved**

Bit 7.

For a Level 4 entry this bit is reserved.

It must be:

```text
RS = 0
```

Do not confuse this with the `PS` Page Size bit found at some lower paging levels. Level 4 does not use bit 7 to create a huge page.

---

**A — Accessed**

Bit 5.

The processor sets this bit when it uses this Level 4 entry during virtual-address translation.

Initially we write:

```text
A = 0
```

Later, after the processor has walked through this entry, hardware may change it to:

```text
A = 1
```

It therefore means more precisely:

```text
"This Level 4 entry has been used during address translation."
```

It does not specifically mean that one individual 4 KB page was accessed.

---

**PCD — Page-level Cache Disable**

Bit 4.

For a Level 4 entry, this participates in determining the caching behavior used when the processor accesses the referenced Level 3 (PDPT) table.

```text
PCD = 0   normal/cacheable behavior
PCD = 1   cache-disable setting
```

For our normal RAM page tables:

```text
PCD = 0
```

---

**PWT — Page-level Write-Through**

Bit 3.

This also participates in determining the caching behavior used when accessing the referenced Level 3 (PDPT).

```text
PWT = 0   normal write-back-style caching
PWT = 1   write-through setting
```

For our page tables:

```text
PWT = 0
```

---

**U/S — User / Supervisor**

Bit 2.

This controls whether user-mode code can access addresses through this entire Level 4 branch.

```text
U/S = 0   supervisor/kernel access only
U/S = 1   user-mode access may be allowed
```

For our bootloader/kernel:

```text
U/S = 0
```

Because we are currently running privileged kernel code and have no user processes yet.

---

**R/W — Read / Write**

Bit 1.

This controls whether writes may be allowed through this Level 4 branch.

```text
R/W = 0   writes restricted
R/W = 1   writes allowed
```

For our initial mappings:

```text
R/W = 1
```

because Stage 2 needs writable memory.

---

**P — Present**

Bit 0.

This tells the processor whether this Level 4 entry actually references a valid Level 3 (PDPT).

```text
P = 0   no valid Level 3 table through this entry
P = 1   this entry references a valid Level 3 table
```

For `PML4[0]`:

```text
P = 1
```

because we created our Level 3 (PDPT) at 100 KB.

---

## Our PML4[0] values

For our current bootloader:

```text
NX   = 0
IG   = 0
ADR  = physical address of Level 3 (PDPT) at 100 KB
R*   = 0
RS   = 0
A    = 0
PCD  = 0
PWT  = 0
U/S  = 0
R/W  = 1
P    = 1
```

So the important bottom six bits are:

```text
+------+---+-----+-----+-----+-----+---+
| bit  | 5 |  4  |  3  |  2  |  1  | 0 |
+------+---+-----+-----+-----+-----+---+
| name | A | PCD | PWT | U/S | R/W | P |
+------+---+-----+-----+-----+-----+---+
| val  | 0 |  0  |  0  |  0  |  1  | 1 |
+------+---+-----+-----+-----+-----+---+
```

Therefore:

```text
000011
    ^^
    ||
    |└── Present = 1
    └── Read/Write = 1
```

Everything else that we do not currently need is deliberately initialized to `0`.
