Once you see the registers laid out, `CR4.PAE`, `CR0.PG`, `EFER.LME`, etc. stop looking mysterious.

The four registers that matter to **our current long-mode transition** are:

```text
CR0       fundamental CPU mode/control switches
CR3       address of our paging-tree root
CR4       additional CPU feature switches
IA32_EFER extended features, including long mode
```

One important correction in terminology:

> There is no “LME register.”
> **LME is one bit inside the 64-bit `IA32_EFER` register.**

---

# 1. CR0 — Control Register 0

CR0 is fundamentally a set of CPU switches.

In 64-bit form, the upper 32 bits are reserved, so the meaningful layout is the lower 32 bits:

```text
+------+----+----+----+----------+----+----+----+----------+----+----+----+----+----+----+----+
| bit  | 31 | 30 | 29 | 28..19   | 18 | 17 | 16 | 15..6    | 5  | 4  | 3  | 2  | 1  | 0  |
+------+----+----+----+----------+----+----+----+----------+----+----+----+----+----+----+----+
| name | PG | CD | NW | Reserved | AM | RS | WP | Reserved | NE | ET | TS | EM | MP | PE |
+------+----+----+----+----------+----+----+----+----------+----+----+----+----+----+----+----+
```

And:

```text
bits 63..32 = Reserved = 0 in 64-bit mode
```

Intel and AMD document this basic layout consistently. ([Intel CDRD][1])

### What each bit means

**PE — Protection Enable — bit 0**

```text
0 = real mode
1 = protected mode enabled
```

We already set this:

```text
CR0.PE = 1
```

---

**MP — Monitor Coprocessor — bit 1**

Old FPU-related behavior. Controls how `WAIT/FWAIT` interacts with FPU task switching.

For us right now: **leave it alone**.

---

**EM — Emulation — bit 2**

```text
0 = hardware floating point can be used
1 = pretend there is no usable FPU; FPU instructions fault
```

Historically allowed software floating-point emulation.

---

**TS — Task Switched — bit 3**

Used to help manage FPU/SIMD state between tasks.

Later useful for process switching.

---

**ET — Extension Type — bit 4**

Ancient historical bit distinguishing old x87 coprocessors.

On modern x86 processors it is effectively fixed to:

```text
ET = 1
```

We don't care about it.

---

**NE — Numeric Error — bit 5**

Controls how x87 floating-point errors are reported.

Modern operating systems normally use the CPU's native exception mechanism.

---

**WP — Write Protect — bit 16**

Important later.

```text
WP = 0
kernel may bypass some read-only page protection

WP = 1
kernel also respects read-only PTE permissions
```

Modern kernels normally enable this.

---

**AM — Alignment Mask — bit 18**

Participates in alignment checking.

Helps detect improperly aligned memory accesses under certain conditions.

---

**NW — Not Write-through — bit 29**

Controls CPU caching behavior.

Low-level cache configuration. Not relevant to entering long mode.

---

**CD — Cache Disable — bit 30**

```text
0 = CPU caching normally enabled
1 = CPU caching disabled
```

Normally leave it alone.

---

**PG — Paging — bit 31**

This one matters enormously:

```text
0 = paging OFF
1 = paging ON
```

Right now:

```text
CR0.PE = 1
CR0.PG = 0
```

Later:

```text
CR0.PG = 1
```

will finally activate our page tables.

So for us CR0 can mentally be reduced to:

```text
CR0

31                                      0
↓                                       ↓
PG                                      PE
│                                       │
paging                                  protected mode
```

---

# 2. CR3 — Paging-tree root

CR3 is very different.

It is mostly an **address**, not a collection of unrelated switches.

For our 4-level paging with PCID disabled:

```text
+------+---------------------+---------+-----+-----+---------+
| bits | 51 ............. 12 | 11 .. 5 |  4  |  3  | 2 .. 0 |
+------+---------------------+---------+-----+-----+---------+
| name | PML4 ADDRESS        | Ignored | PCD | PWT | Ignored |
+------+---------------------+---------+-----+-----+---------+
```

Above the CPU-supported physical-address width, bits must be zero. The PML4 address is 4 KB aligned, so its bottom 12 address bits are implicit zeros. ([Intel CDRD][2])

### ADDRESS

This is the physical address of:

```text
Level 4 (PML4) = Page Map Level 4
```

Our PML4 is at:

```text
96 KB
= 98304 bytes
= 0x18000
```

So eventually:

```text
CR3 = 98304
```

and the CPU understands:

```text
CR3
 ↓
96 KB
 ↓
PML4
 ↓
PDPT
 ↓
PD
 ↓
PT
```

---

**PWT — Page Write-Through — bit 3**

Controls caching behavior when the CPU accesses the top-level paging structure.

For us:

```text
PWT = 0
```

---

**PCD — Page Cache Disable — bit 4**

Controls whether the top-level paging structure is cache-disabled.

For us:

```text
PCD = 0
```

So our CR3 is beautifully simple:

```text
CR3 = 96 KB
```

No extra flags needed.

---

# 3. CR4 — Additional CPU feature switches

CR4 is another bank of switches.

The common x86-64 portion looks like this:

```text
+------+-----+-----+-----+-----+------+-----+------+-----+------+--------+--------+
| bit  | 22  | 21  | 20  | 19  | 18   | 17  | 16   | 15  | 14   | 13     | 12     |
+------+-----+-----+-----+-----+------+-----+------+-----+------+--------+--------+
| name | PKE |SMAP |SMEP | *   |OSXSAV|PCIDE|FSGSBA| RS  | SMXE*| VMXE*  | LA57   |
+------+-----+-----+-----+-----+------+-----+------+-----+------+--------+--------+

+------+-----+----------+--------+-------+-----+-----+-----+-----+-----+-----+-----+-----+
| bit  | 11  |    10    |   9    |   8   |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
+------+-----+----------+--------+-------+-----+-----+-----+-----+-----+-----+-----+-----+
| name |UMIP |OSXMMEXCP | OSFXSR | PCE   | PGE | MCE | PAE | PSE | DE  | TSD | PVI | VME |
+------+-----+----------+--------+-------+-----+-----+-----+-----+-----+-----+-----+-----+
```

The really important warning here is that **the upper CR4 feature bits vary somewhat between Intel and AMD and between CPU generations**. Features must generally be checked with `CPUID` before being enabled. But `PAE = bit 5` is common and exactly what our bootstrap needs. ([AMD Documentation][3])

Very briefly:

**VME — bit 0**

Virtual-8086-mode enhancements.

Ancient compatibility feature.

---

**PVI — bit 1**

Protected-mode virtual interrupts.

Another legacy virtualization feature.

---

**TSD — bit 2**

Controls whether low-privilege programs may use the timestamp counter instruction `RDTSC`.

---

**DE — bit 3**

Debugging extensions.

---

**PSE — bit 4**

Page Size Extensions.

Supports larger pages in older paging modes.

---

## **PAE — bit 5**

Our important one:

**Physical Address Extension**

```text
CR4.PAE = 1
```

enables the extended paging machinery required for x86-64 paging.

---

**MCE — bit 6**

Machine Check Enable.

Allows the CPU to report serious hardware failures through machine-check exceptions.

---

**PGE — bit 7**

Page Global Enable.

Allows pages marked global to survive certain TLB flushes.

Useful for kernel pages later.

---

**PCE — bit 8**

Controls whether user programs can access performance-monitoring counters.

---

**OSFXSR — bit 9**

Says:

> “My OS knows how to save/restore SSE/XMM state using FXSAVE/FXRSTOR.”

Important later.

---

**OSXMMEXCPT — bit 10**

Says:

> “My OS knows how to handle SIMD floating-point exceptions.”

---

**UMIP — bit 11**

User Mode Instruction Prevention.

Stops user programs from executing certain system-information instructions.

Security feature.

---

**LA57 — bit 12**

Enables **5-level paging**.

We are deliberately using:

```text
LA57 = 0
```

because we're building normal **4-level paging**.

---

**VMXE — bit 13**

Intel virtualization (`VMX`) enable.

Intel-specific.

We don't need it.

---

**SMXE — bit 14**

Intel Secure Mode Extensions.

We don't need it.

---

**FSGSBASE — bit 16**

Allows special instructions for reading/writing FS and GS base addresses.

Useful later.

---

**PCIDE — bit 17**

Enables Process Context Identifiers.

Advanced paging/TLB optimization.

We aren't using it.

---

**OSXSAVE — bit 18**

Says the OS supports XSAVE/XRSTOR and extended CPU state management.

Useful much later for AVX etc.

---

**SMEP — bit 20**

Supervisor Mode Execution Prevention.

Helps prevent the kernel from accidentally executing user pages.

Security feature.

---

**SMAP — bit 21**

Supervisor Mode Access Prevention.

Helps prevent the kernel from accidentally accessing user pages.

Security feature.

---

**PKE — bit 22**

Protection Keys for user pages.

Advanced memory protection.

Not needed now.

Modern CPUs define additional CR4 bits above this—for example CET and, on Intel, PKS/UINTR/LASS/LAM-related features—but those are later-generation, vendor-qualified features and irrelevant to our bootstrap. ([Intel CDRD][4])

For **our current OS**, CR4 can mentally collapse to:

```text
CR4

bit 5
  ↓
 PAE
  ↓
set to 1
```

Everything else:

> **preserve whatever value it already has.**

That is why we'll use read → OR → write.

---

# 4. IA32_EFER — Extended Feature Enable Register

This is the register containing **LME**.

It is a **64-bit MSR**:

```text
IA32_EFER
```

On Intel, its core architectural layout is wonderfully small:

```text
+------+-------------+-----+-----+-----+-----+------------+-----+
| bits | 63 ......12 | 11  | 10  |  9  |  8  | 7 ......1 |  0  |
+------+-------------+-----+-----+-----+-----+------------+-----+
| name | Reserved    | NXE | LMA | RS  | LME | Reserved   | SCE |
+------+-------------+-----+-----+-----+-----+------------+-----+
```

([Intel CDRD][1])

### SCE — bit 0

**System Call Enable**

Enables:

```text
SYSCALL
SYSRET
```

We'll care about this much later when implementing system calls.

For now:

```text
SCE = 0
```

---

## LME — bit 8

**Long Mode Enable**

This is our important bit.

```text
LME = 0
long mode not requested

LME = 1
long mode enabled/requested
```

Setting it does **not immediately put us in long mode**.

It prepares the CPU so that when paging is enabled, long mode can activate.

---

## LMA — bit 10

**Long Mode Active**

This one is especially cool.

LME says:

```text
"I WANT long mode."
```

LMA says:

```text
"I AM actually in long mode."
```

We don't directly turn LMA on.

The CPU sets it when the necessary conditions are satisfied:

```text
LME = 1
AND
PG = 1
        ↓
LMA becomes 1
```

Intel explicitly describes LMA as the status indication for active IA-32e mode. ([Intel][5])

---

## NXE — bit 11

**No-Execute Enable**

Enables the `NX`/`XD` bit in page-table entries.

When enabled, pages can be marked:

```text
data only
DO NOT execute instructions here
```

Very important for security later.

We can initially leave:

```text
NXE = 0
```

because all our PTE NX bits are currently zero anyway.

---

# AMD adds some extra EFER bits

Because AMD originally created AMD64, AMD processors define several additional EFER features above bit 11, such as:

```text
12  SVME     AMD virtualization
13  LMSLE    segment-limit behavior
14  FFXSR    faster FXSAVE/FXRSTOR behavior
15  TCE      translation-cache behavior
17  MCOMMIT  MCOMMIT instruction
...
```

Modern AMD documentation defines additional higher bits as well. Intel leaves those corresponding EFER positions reserved. ([AMD Documentation][3])

Again, **none of them matter to our bootstrap**.

---

# Put all four registers together

This is the picture I want you to remember:

```text
CR0
┌────────────────────────────────┐
│ PE                         PG  │
│ ↑                          ↑   │
│ protected mode             paging
└────────────────────────────────┘

Right now:
PE = 1
PG = 0
```

```text
CR4
┌────────────────────────────────┐
│             PAE                │
│              ↑                 │
│ extended paging machinery      │
└────────────────────────────────┘

Next:
PAE = 1
```

```text
CR3
┌────────────────────────────────┐
│ physical address of PML4       │
│                                │
│ 96 KB                          │
└────────────────────────────────┘
```

```text
IA32_EFER
┌────────────────────────────────┐
│ SCE      LME    LMA    NXE     │
│          ↑      ↑              │
│       enable   active           │
└────────────────────────────────┘

We set:
LME = 1

CPU later sets:
LMA = 1
```

And therefore our transition is no longer alphabet soup:

```text
CR4.PAE = 1
     ↓
"Use the paging machinery required by long mode."


CR3 = 96 KB
     ↓
"My paging tree begins here."


EFER.LME = 1
     ↓
"I want long mode."


CR0.PG = 1
     ↓
"Turn paging on."
     ↓
CPU sets EFER.LMA = 1
     ↓
IA-32e mode is ACTIVE


far jump to 64-bit code descriptor
     ↓
actually execute 64-bit code
```

That's really what those registers are doing. Once laid out as bits and switches, there is very little mystery left.

[1]: https://cdrdv2-public.intel.com/874240/325462-090-sdm-vol-1-2abcd-3abcd-4.pdf?utm_source=chatgpt.com "Intel® 64 and IA-32 Architectures Software Developer's Manual, Combined Volumes: 1, 2A, 2B, 2C, 2D, 3A, 3B, 3C, 3D, and 4"
[2]: https://cdrdv2-public.intel.com/671190/253668-sdm-vol-3a.pdf?utm_source=chatgpt.com "Intel® 64 and IA-32 Architectures Software Developer’s Manual, Volume 3A: System Programming Guide, Part 1"
[3]: https://docs.amd.com/api/khub/documents/sD1_QL~h4Afq2_tvzxqqSQ/content?utm_source=chatgpt.com "AMD64 Architecture Programmer’s Manual, Volume 2: System Programming"
[4]: https://cdrdv2-public.intel.com/868137/325462-089-sdm-vol-1-2abcd-3abcd-4.pdf?utm_source=chatgpt.com "Intel® 64 and IE-21 Architectures Software Developer's Manual, Combined Volumes: 1, 2, 3, and 4"
[5]: https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-system-programming-manual-325384.pdf?utm_source=chatgpt.com "Intel® 64 and IA-32 Architectures Software Developer’s Manual, Volume 3 (3A, 3B, 3C & 3D): System Programming Guide"
