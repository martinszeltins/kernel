# ATA Disk Reading Manual

## Scope

This manual documents the exact disk interface used by our educational x86 kernel:

- x86 / x86-64
- QEMU PC
- one ATA/IDE hard disk
- primary ATA channel
- device 0 / “master”
- classic ATA task-file I/O ports
- 28-bit LBA addressing
- PIO reads
- 512-byte logical sectors
- polling instead of interrupts
- no BIOS calls

The goal is to understand the hardware interface completely enough to read sectors ourselves.

This is **not the entire ATA standard**. ATA evolved for decades and contains later 48-bit LBA, DMA, SATA, NCQ, ATAPI, vendor-specific commands, security features, power management, and many other features. This document fully covers the legacy task-file API and the complete path we need for a classic 28-bit PIO sector read.

---

# 1. The big picture

Stage 1 used the BIOS:

```text
our Stage 1
    ↓
BIOS INT 13h
    ↓
ATA/IDE hardware
    ↓
disk
```

Now we remove the BIOS:

```text
our Stage 2 / kernel
    ↓
IN / OUT instructions
    ↓
ATA I/O ports
    ↓
ATA task-file registers
    ↓
disk
```

The operation feels a little like calling an API.

A high-level API might look like:

```js
readDisk({
    lba: 0,
    count: 1
})
```

ATA makes us serialize that request manually into hardware registers:

```text
select drive/addressing mode
set sector count
set starting LBA
issue READ command
wait for response
read response data
```

---

# 2. Port versus register

These words are related but are not the same thing.

An **I/O port** is an x86 I/O-space address.

Example:

```text
0x1F2
```

A **hardware register** is a small piece of hardware state/function accessed through that port.

Example:

```text
I/O port 0x1F2
        ↓
ATA Sector Count register
```

So:

```text
0x1F2 = I/O address
Sector Count = register/function reached through that address
```

The same I/O address may expose different registers depending on whether the CPU reads or writes it.

Example:

```text
port 0x1F7

OUT / write → Command register
IN  / read  → Status register
```

---

# 3. Our QEMU disk

Use the disk as the first IDE disk:

```bash
qemu-system-x86_64 \
    -drive format=raw,file=disk.img,if=ide,index=0
```

For this manual we assume that this gives us the first ATA/IDE disk on the primary channel.

Our conceptual machine is:

```text
CPU
 ↓
primary ATA channel
 ↓
device 0 / master
 ↓
disk.img
```

We deliberately ignore multiple disks and multiple channels for now.

---

# 4. Disk sectors and LBA

## 4.1 Sector

For our disk interface, one logical sector is:

```text
512 bytes
```

The disk is viewed as a sequence of numbered 512-byte blocks:

```text
disk.img

LBA 0     bytes 0–511
LBA 1     bytes 512–1023
LBA 2     bytes 1024–1535
LBA 3     bytes 1536–2047
...
```

## 4.2 LBA

**LBA = Logical Block Address.**

For our purposes:

> LBA is simply the sector number.

So:

```text
LBA 0 = first sector
LBA 1 = second sector
LBA 2 = third sector
```

Our Stage 1 boot sector is at:

```text
LBA 0
```

Therefore our first experiment is:

```text
start LBA    = 0
sector count = 1
```

The result is exactly:

```text
512 bytes
```

---

# 5. The primary ATA task-file I/O ports

The classic primary ATA command block lives at:

```text
0x1F0–0x1F7
```

There is also a control/status port at:

```text
0x3F6
```

Full map:

```text
PRIMARY ATA / IDE TASK-FILE INTERFACE

PORT       WRITE                          READ
────────────────────────────────────────────────────────────────

0x1F0      Data                           Data
           host → device                  device → host
           16-bit for normal PIO data transfers

0x1F1      Features                       Error
           command-specific options       error details

0x1F2      Sector Count                   Sector Count
           number of sectors

0x1F3      LBA Low                        LBA Low
           LBA bits 0–7

0x1F4      LBA Mid                        LBA Mid
           LBA bits 8–15

0x1F5      LBA High                       LBA High
           LBA bits 16–23

0x1F6      Device / Head                  Device / Head
           drive selection
           LBA/CHS mode
           LBA bits 24–27 in LBA28 mode

0x1F7      Command                        Status
           submit operation               device state

0x3F6      Device Control                 Alternate Status
           reset / interrupt control       status without
                                           acknowledging IRQ
```

This group of ATA registers is historically called the **task file**.

You can think of the task file as a tiny request/response structure shared between the host and disk interface.

---

# 6. Data register — port 0x1F0

## Direction

```text
READ  0x1F0 → data from disk
WRITE 0x1F0 → data to disk
```

For our `READ SECTOR(S)` PIO operation, data moves:

```text
disk
 ↓
ATA buffer
 ↓
port 0x1F0
 ↓
CPU
 ↓
RAM
```

Normal sector data is transferred 16 bits at a time.

```text
one IN AX, DX
=
16 bits
=
2 bytes
```

One sector is:

```text
512 bytes
```

Therefore:

```text
512 / 2 = 256
```

We perform:

```text
256 × 16-bit reads
```

for one sector.

Conceptually:

```text
read word 0   → bytes 0–1
read word 1   → bytes 2–3
read word 2   → bytes 4–5
...
read word 255 → bytes 510–511
```

Assembly can do this manually:

```asm
mov dx, 0x1F0
in ax, dx
mov [rdi], ax
```

or with the x86 string-I/O instruction:

```asm
mov dx, 0x1F0
mov rcx, 256
cld
rep insw
```

In 64-bit mode, `RDI` is the destination pointer and `RCX` is the repetition count. `cld` ensures that the Direction Flag is clear, so `RDI` increases after each word.

---

# 7. Features / Error register — port 0x1F1

This address has two meanings.

```text
WRITE 0x1F1 → Features register
READ  0x1F1 → Error register
```

## 7.1 Features register — write

The Features register supplies command-specific options or subcommands.

For our simple `READ SECTOR(S)` command:

```text
we do not need to write anything useful here
```

Other commands, such as `SET FEATURES` or `SMART`, use this register to specify additional operations.

So ATA commands can behave like:

```text
command = SMART
feature = READ SMART DATA
```

This is similar to an API operation plus a sub-operation.

## 7.2 Error register — read

If the Status register reports:

```text
ERR = 1
```

read port `0x1F1` to obtain more information.

Classic error-byte format:

```text
bit:    7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │ BBK/ │ UNC  │  MC  │ IDNF │ MCR  │ ABRT │TK0NF │ AMNF │
      │ ICRC │      │      │      │      │      │      │      │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

The exact historical meaning of some bits changed as ATA evolved.

- **Bit 7 — BBK / ICRC:** older `BBK = Bad Block`; later `ICRC = Interface CRC error`. CRC means Cyclic Redundancy Check.
- **Bit 6 — UNC:** Uncorrectable data error.
- **Bit 5 — MC:** Media Changed.
- **Bit 4 — IDNF:** ID Not Found; historically the requested sector identification could not be found.
- **Bit 3 — MCR:** Media Change Request.
- **Bit 2 — ABRT:** Aborted Command. Very useful when a malformed or unsupported command is rejected.
- **Bit 1 — TK0NF:** Track 0 Not Found; historical CHS-era meaning.
- **Bit 0 — AMNF:** Address Mark Not Found; historical magnetic-disk meaning.

For our QEMU read, the most useful error concepts are:

```text
UNC
IDNF
ABRT
```

---

# 8. Sector Count register — port 0x1F2

This is an 8-bit field:

```text
bit:

7 6 5 4 3 2 1 0
┌───────────────┐
│ sector count  │
└───────────────┘
```

For 28-bit `READ SECTOR(S)`:

```text
0x01 = 1 sector
0x02 = 2 sectors
...
0xFF = 255 sectors
0x00 = 256 sectors
```

The zero case is special: **zero does not mean zero sectors; it means 256 sectors.**

For our first read:

```asm
mov dx, 0x1F2
mov al, 1
out dx, al
```

means:

> Transfer exactly one sector.

---

# 9. The 28-bit LBA field

A 28-bit LBA does not fit inside one 8-bit ATA register.

So ATA splits the 28-bit sector number across four locations:

```text
                 COMPLETE 28-BIT LBA

LBA bit:

27 26 25 24   23 ........ 16   15 ........ 8   7 ........ 0
┌───────────┬─────────────────┬────────────────┬───────────────┐
│  4 bits   │      8 bits     │     8 bits     │    8 bits     │
└─────┬─────┴────────┬────────┴───────┬────────┴───────┬───────┘
      │              │                │                │
      ▼              ▼                ▼                ▼
0x1F6 bits 3–0     0x1F5           0x1F4           0x1F3
LBA 24–27          LBA 16–23       LBA 8–15        LBA 0–7
```

Therefore:

```text
0x1F3 ← LBA bits 0–7
0x1F4 ← LBA bits 8–15
0x1F5 ← LBA bits 16–23
0x1F6 ← LBA bits 24–27 in its low four bits
```

For an arbitrary 28-bit LBA value:

```text
LBA low  = (LBA >> 0)  & 0xFF
LBA mid  = (LBA >> 8)  & 0xFF
LBA high = (LBA >> 16) & 0xFF
LBA top  = (LBA >> 24) & 0x0F
```

For LBA 0:

```text
0000 00000000 00000000 00000000
```

so all four LBA pieces are zero.

A 28-bit number gives 268,435,456 possible sector addresses, from `0` through `268,435,455`. At 512 bytes per sector this addresses 137,438,953,472 bytes, about 137.4 GB.

---

# 10. LBA Low — port 0x1F3

```text
bit:     7     6     5     4     3     2     1     0
      ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
      │LBA7 │LBA6 │LBA5 │LBA4 │LBA3 │LBA2 │LBA1 │LBA0 │
      └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
```

Historically, in CHS mode, this was called the **Sector Number register**.

---

# 11. LBA Mid — port 0x1F4

```text
bit:      7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │LBA15 │LBA14 │LBA13 │LBA12 │LBA11 │LBA10 │ LBA9 │ LBA8 │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

Historically this was **Cylinder Low**.

---

# 12. LBA High — port 0x1F5

```text
bit:      7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │LBA23 │LBA22 │LBA21 │LBA20 │LBA19 │LBA18 │LBA17 │LBA16 │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

Historically this was **Cylinder High**.

---

# 13. Device / Head register — port 0x1F6

In classic 28-bit LBA mode:

```text
bit:     7      6      5      4       3       2       1       0
      ┌──────┬──────┬──────┬──────┬───────┬───────┬───────┬───────┐
      │ OBS  │ LBA  │ OBS  │ DEV  │ LBA27 │ LBA26 │ LBA25 │ LBA24 │
      └──────┴──────┴──────┴──────┴───────┴───────┴───────┴───────┘
```

## Bit 7 — OBS

Modern ATA meaning: **obsolete**.

Historically, an ancestor of this register was the Size/Drive/Head register used by early Western Digital PC hard-disk controllers. On such controllers, bit 7 could enable error-correction/checking circuitry.

That programming shape survived into the IBM PC/AT disk interface and then ATA/IDE compatibility. Traditional ATA software therefore commonly writes this obsolete bit as `1`.

## Bit 6 — LBA

```text
0 = CHS addressing
1 = LBA addressing
```

We use `1`.

## Bit 5 — OBS

Modern ATA meaning: **obsolete**.

Historically this position participated in old disk-sector-size selection on predecessor controllers. PC hard disks standardized around 512-byte sectors, and the old bit pattern became legacy baggage. Traditional ATA software commonly writes this bit as `1`.

## Bit 4 — DEV

```text
0 = device 0 / master
1 = device 1 / slave
```

We use `0`.

## Bits 3–0 — LBA bits 27–24

```text
bit 3 = LBA27
bit 2 = LBA26
bit 1 = LBA25
bit 0 = LBA24
```

In old CHS mode these positions represented the head number.

## Our LBA-0 value

```text
bit 7 = 1       traditional obsolete bit
bit 6 = 1       LBA mode
bit 5 = 1       traditional obsolete bit
bit 4 = 0       device 0
bits 3–0 = 0000 LBA[27:24]
```

Therefore:

```text
11100000 binary = 0xE0
```

For an arbitrary LBA on device 0:

```text
device byte = 0xE0 | ((LBA >> 24) & 0x0F)
```

---

# 14. Command / Status — port 0x1F7

```text
WRITE 0x1F7 → Command
READ  0x1F7 → Status
```

---

# 15. Command register — writing 0x1F7

The command register is one 8-bit **opcode**:

```text
7 6 5 4 3 2 1 0
┌───────────────┐
│ command code  │
└───────────────┘
```

The byte is normally interpreted as one operation number, not eight independent flags.

The command-byte namespace is `0x00` through `0xFF`, but ATA does not define one universal operation for every value. Across revisions, values can be defined, obsolete, retired, reserved, feature-specific, CompactFlash-specific, ATAPI-related, or vendor-specific.

Important read-related commands:

```text
0x20   READ SECTOR(S)          28-bit LBA, PIO Data-In — our command
0x24   READ SECTOR(S) EXT      48-bit LBA, PIO Data-In
0x25   READ DMA EXT            48-bit DMA
0x29   READ MULTIPLE EXT       48-bit PIO block transfer
0x40   READ VERIFY SECTOR(S)   verifies without returning sector data
0x42   READ VERIFY EXT         48-bit version
0xC4   READ MULTIPLE           PIO block transfer
0xC8   READ DMA                28-bit DMA
0xEC   IDENTIFY DEVICE         returns 512 bytes describing the drive
```

Other important ATA command families:

```text
0x00   NOP
0x08   DEVICE RESET

0x30   WRITE SECTOR(S)
0x34   WRITE SECTOR(S) EXT
0x35   WRITE DMA EXT
0x39   WRITE MULTIPLE EXT
0xC5   WRITE MULTIPLE
0xC6   SET MULTIPLE MODE
0xCA   WRITE DMA

0xE0   STANDBY IMMEDIATE
0xE1   IDLE IMMEDIATE
0xE2   STANDBY
0xE3   IDLE
0xE5   CHECK POWER MODE
0xE6   SLEEP
0xE7   FLUSH CACHE
0xEA   FLUSH CACHE EXT

0x90   EXECUTE DEVICE DIAGNOSTIC
0x91   INITIALIZE DEVICE PARAMETERS
0x92   DOWNLOAD MICROCODE

0xA0   PACKET
0xA1   IDENTIFY PACKET DEVICE
0xA2   SERVICE

0xB0   SMART

0xEF   SET FEATURES

0xF1   SECURITY SET PASSWORD
0xF2   SECURITY UNLOCK
0xF3   SECURITY ERASE PREPARE
0xF4   SECURITY ERASE UNIT
0xF5   SECURITY FREEZE LOCK
0xF6   SECURITY DISABLE PASSWORD

0xF8   READ NATIVE MAX ADDRESS
0xF9   SET MAX ADDRESS
```

Later ATA revisions added many more commands for 48-bit LBA, SATA, queueing, logs, streaming, trusted-computing features, and NCQ.

Our command is:

```text
0x20 = READ SECTOR(S), 28-bit LBA, PIO Data-In
```

---

# 16. Status register — reading 0x1F7

Classic layout:

```text
bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │ BSY  │ DRDY │  DF  │ DSC  │ DRQ  │ CORR │ IDX  │ ERR  │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

Some lower positions became obsolete or were repurposed in later ATA revisions.

## Bit 7 — BSY

`BSY = Busy`.

```text
1 = device busy
0 = device not busy
```

Critical rule:

> While BSY is 1, do not trust the other status bits.

Mask:

```text
0x80
```

## Bit 6 — DRDY

`DRDY = Device Ready`.

Traditionally indicates the selected device is ready for suitable commands.

Mask:

```text
0x40
```

## Bit 5 — DF

`DF = Device Fault`.

Treat this as failure after BSY clears.

Mask:

```text
0x20
```

## Bit 4 — DSC

Historically `DSC = Device Seek Complete`, reflecting mechanical-drive positioning. Later standards deprecated/repurposed this position for other protocols. We do not use it.

## Bit 3 — DRQ

`DRQ = Data Request`.

For a read:

```text
DRQ = 1
```

means the device has data ready for the host to transfer through `0x1F0`.

Mask:

```text
0x08
```

## Bit 2 — CORR

Historically `CORR = Corrected Data`. Obsolete/not useful for our simple reader.

## Bit 1 — IDX

Historically `IDX = Index`, an old rotational-disk concept. Obsolete/repurposed later.

## Bit 0 — ERR

`ERR = Error`.

If set after BSY clears, read the Error register at `0x1F1`.

Mask:

```text
0x01
```

For our read, the state we want is:

```text
BSY = 0
DF  = 0
ERR = 0
DRQ = 1
```

---

# 17. Alternate Status / Device Control — port 0x3F6

```text
READ  0x3F6 → Alternate Status
WRITE 0x3F6 → Device Control
```

## Alternate Status

Reports essentially the same status information as `0x1F7`, but reading it does **not** acknowledge/clear a pending ATA interrupt.

This makes it useful for polling and timing.

## Device Control

Classic relevant layout:

```text
bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │ HOB  │ RSV  │ RSV  │ RSV  │ OBS  │ SRST │ nIEN │ RSV  │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

- **HOB, bit 7:** High Order Byte; used with 48-bit LBA register access.
- **Bits 6–4:** reserved for this use.
- **Bit 3:** obsolete historical bit.
- **SRST, bit 2:** Software Reset. Used for ATA software-reset/recovery.
- **nIEN, bit 1:** interrupt-disable control. `0 = interrupts enabled`, `1 = interrupts disabled`.
- **Bit 0:** reserved.

Our early-boot reader uses polling, not ATA interrupts.

---

# 18. ATA timing — the roughly 400 ns waits

ATA is a physical hardware protocol. After transitions such as selecting a device or issuing a command, the device needs a short period before status is guaranteed to reflect the new state.

Classic ATA procedures contain waits of roughly:

```text
400 nanoseconds
```

A common legacy technique is repeated reads of Alternate Status:

```asm
mov dx, 0x3F6
in al, dx
in al, dx
in al, dx
in al, dx
```

This creates I/O cycles and gives the device time to settle.

Important: **four reads are not a universal mathematical guarantee of exactly 400 ns on every implementation.** The real requirement is the timing delay; repeated alternate-status reads are a traditional implementation technique. Production drivers may use explicit timing machinery.

QEMU is much more forgiving than real legacy hardware, but keeping this step teaches the actual protocol.

---

# 19. Complete READ SECTOR(S) request

We want:

```text
device       = 0 / master
address mode = LBA
start LBA    = 0
count        = 1
command      = READ SECTOR(S)
```

Hardware serialization:

```text
0x1F6 ← 11100000    device 0 + LBA + LBA[27:24]=0000
0x1F2 ← 00000001    1 sector
0x1F3 ← 00000000    LBA[7:0]
0x1F4 ← 00000000    LBA[15:8]
0x1F5 ← 00000000    LBA[23:16]
0x1F7 ← 00100000    command 0x20 = READ SECTOR(S)
```

Then:

```text
wait for BSY=0, ERR=0, DF=0, DRQ=1
                   ↓
read 256 words from 0x1F0
                   ↓
512 bytes copied into RAM
```

---

# 20. Full command sequence

## Step 1 — wait until the device is not busy

Read status or alternate status.

```text
BSY = 1 → wait
BSY = 0 → continue
```

## Step 2 — select device 0 and LBA mode

Write:

```text
0xE0 | ((LBA >> 24) & 0x0F)
```

to `0x1F6`.

For LBA 0:

```text
0xE0
```

## Step 3 — allow device-selection settling time

Wait roughly 400 ns.

## Step 4 — write Sector Count

For one sector:

```text
0x1F2 ← 1
```

## Step 5 — write LBA low/mid/high

For LBA 0:

```text
0x1F3 ← 0
0x1F4 ← 0
0x1F5 ← 0
```

## Step 6 — submit READ SECTOR(S)

```text
0x1F7 ← 0x20
```

This write is the moment the request is submitted. Before it, we are only filling request parameters.

## Step 7 — allow status-update time

Wait roughly 400 ns before trusting freshly updated status.

## Step 8 — poll

```text
if BSY = 1:
    wait

if ERR = 1:
    fail, then read 0x1F1

if DF = 1:
    fail

if DRQ = 1:
    data is ready

otherwise:
    continue waiting
```

## Step 9 — transfer data

Read:

```text
256 × 16-bit words
```

from `0x1F0`.

That is:

```text
256 × 2 bytes = 512 bytes
```

## Step 10 — final status check

A robust implementation checks that the command completed without `BSY`, `ERR`, or `DF`.

---

# 21. Our RAM destination

Our current map leaves a gap immediately below the page tables:

```text
Stage 2 ends around 95 KB
96 KB begins Level 4 (PML4)
```

One sector is `0.5 KB`, so a convenient temporary buffer is:

```text
95 KB = 97,280 bytes = 0x17C00
```

The copied sector occupies:

```text
0x17C00 through 0x17DFF
```

which is exactly 512 bytes.

---

# 22. Full simple 64-bit assembly example

```asm
; -----------------------------------------------------------------------------
; Read LBA 0, one 512-byte sector, using primary ATA PIO.
;
; Assumptions:
;   - QEMU IDE disk is primary device 0 / master
;   - 28-bit LBA
;   - 512-byte sectors
;   - polling, not interrupts
;   - destination 95 KB (0x17C00) is identity mapped and writable
; -----------------------------------------------------------------------------

ata_read_lba0:

    ; 1. Wait until device is not busy.
    mov dx, 0x3F6

.wait_initial:
    in al, dx
    test al, 0x80              ; BSY?
    jnz .wait_initial

    ; 2. Select device 0 + LBA mode + LBA[27:24] = 0000.
    ;
    ; 1110 0000
    ; |||| ||||
    ; |||| ++++-- LBA[27:24] = 0000
    ; |||+------- DEV = 0
    ; ||+-------- obsolete traditional bit = 1
    ; |+--------- LBA mode = 1
    ; +---------- obsolete traditional bit = 1
    mov dx, 0x1F6
    mov al, 0b11100000
    out dx, al

    ; 3. Short device-selection settling delay.
    mov dx, 0x3F6
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    ; 4. Sector Count = 1.
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; 5. LBA = 0.
    mov dx, 0x1F3
    xor al, al
    out dx, al

    mov dx, 0x1F4
    out dx, al

    mov dx, 0x1F5
    out dx, al

    ; 6. 0x20 = READ SECTOR(S), PIO Data-In.
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; 7. Short status-update delay.
    mov dx, 0x3F6
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    ; 8. Wait for BSY=0, ERR=0, DF=0, DRQ=1.
    mov dx, 0x1F7

.wait_data:
    in al, dx

    test al, 0x80              ; BSY?
    jnz .wait_data

    test al, 0x01              ; ERR?
    jnz .error

    test al, 0x20              ; DF?
    jnz .fault

    test al, 0x08              ; DRQ?
    jz .wait_data

    ; 9. Transfer 512 bytes = 256 words.
    mov dx, 0x1F0
    mov rdi, 97280             ; 95 KB = 0x17C00
    mov rcx, 256

    cld
    rep insw

    ; 10. Final status check.
    mov dx, 0x1F7

.wait_complete:
    in al, dx

    test al, 0x80
    jnz .wait_complete

    test al, 0x01
    jnz .error

    test al, 0x20
    jnz .fault

.success:
    ; RAM 0x17C00..0x17DFF now contains disk LBA 0.
    jmp .success

.error:
    ; Read detailed ATA Error register.
    mov dx, 0x1F1
    in al, dx
    ; AL now contains the Error byte.
    jmp .error

.fault:
    jmp .fault
```

For a real kernel, replace infinite loops with timeouts, return values, diagnostics, and recovery.

---

# 23. Why real drivers need timeouts

The simple code says:

```text
wait forever
```

That is useful for a first controlled QEMU experiment because it keeps the mechanism visible.

A real driver must do:

```text
while BSY:
    if timeout expired:
        report failure
```

Otherwise a missing or broken device can hang the whole kernel.

---

# 24. Multi-sector reads

If Sector Count is `3`, the request means:

```text
read LBA N
read LBA N+1
read LBA N+2
```

For classic PIO `READ SECTOR(S)`, the device presents data according to the DRQ protocol. A simple implementation should treat each sector as:

```text
wait for DRQ
read 256 words
repeat
```

until all requested sectors are consumed.

For our first read:

```text
count = 1
```

so this complexity does not exist.

---

# 25. Reading an arbitrary LBA

For any valid 28-bit LBA `N`:

```text
0x1F6 ← 0xE0 | ((N >> 24) & 0x0F)
0x1F2 ← sector count
0x1F3 ← (N >> 0)  & 0xFF
0x1F4 ← (N >> 8)  & 0xFF
0x1F5 ← (N >> 16) & 0xFF
0x1F7 ← 0x20
```

Visual split:

```text
N:

27 26 25 24   23 ........ 16   15 ........ 8   7 ........ 0
┌───────────┬─────────────────┬────────────────┬───────────────┐
│ 0x1F6     │     0x1F5      │     0x1F4      │     0x1F3     │
│ low nibble│                 │                │               │
└───────────┴─────────────────┴────────────────┴───────────────┘
```

---

# 26. The ATA API mental model

```text
                         REQUEST

┌────────────────────────────────────────────────────────────────────┐
│ 0x1F6 : device + addressing mode + top LBA bits                   │
│ 0x1F2 : sector count                                              │
│ 0x1F3 : LBA bits 0–7                                              │
│ 0x1F4 : LBA bits 8–15                                             │
│ 0x1F5 : LBA bits 16–23                                            │
│ 0x1F7 : command opcode                                            │
└────────────────────────────────────────────────────────────────────┘

                              ↓

                          ATA DEVICE

                              ↓

                         RESPONSE

┌────────────────────────────────────────────────────────────────────┐
│ 0x1F7 : status                                                     │
│ 0x1F1 : detailed error information if ERR = 1                      │
│ 0x1F0 : actual data when DRQ = 1                                   │
└────────────────────────────────────────────────────────────────────┘
```

Nuxt/API analogy:

```text
Nuxt / GraphQL                  ATA

operation name                  command opcode
arguments                       task-file registers
request payload                 count + LBA + options
submit request                  OUT to command port 0x1F7
server busy                     BSY = 1
response ready                  DRQ = 1
request failed                  ERR = 1 / DF = 1
error response                  Error register 0x1F1
response body                   Data register 0x1F0
```

---

# 27. IDENTIFY DEVICE

Command:

```text
0xEC = IDENTIFY DEVICE
```

This does not read a disk sector. It asks the drive:

> Who are you and what can you do?

The device returns:

```text
512 bytes = 256 16-bit words
```

through `0x1F0`.

The data describes things such as:

```text
model
serial number
firmware revision
capacity
LBA support
supported ATA versions/features
transfer modes
sector information
```

A proper general driver normally identifies/discovers the device instead of hardcoding every assumption.

Our controlled QEMU experiment intentionally skips this step.

---

# 28. PIO versus DMA

**PIO = Programmed Input/Output.**

Our current path:

```text
disk → ATA → CPU → RAM
```

The CPU personally reads the words from `0x1F0`.

**DMA = Direct Memory Access.**

With DMA:

```text
disk → ATA/DMA engine ───→ RAM
              ↑
        CPU sets it up
```

PIO is excellent for learning because every transfer is visible.

---

# 29. 28-bit versus 48-bit LBA

Our command:

```text
0x20 = READ SECTOR(S)
```

uses classic 28-bit LBA.

Later ATA added:

```text
0x24 = READ SECTOR(S) EXT
```

for 48-bit LBA.

48-bit commands reuse the task-file registers in a more elaborate sequence, writing high-order bytes and low-order bytes separately.

Do not mix the two protocols.

For now:

```text
28-bit LBA
0x20
one QEMU disk
```

is our entire world.

---

# 30. Polling versus interrupts

Our driver polls:

```text
read Status
read Status
read Status
...
```

A later driver can instead use hardware interrupts:

```text
issue command
do other work
disk raises IRQ when ready
CPU enters interrupt handler
driver handles transfer/completion
```

Polling is ideal for early boot because it avoids needing an IDT handler, interrupt-controller setup, and IRQ routing.

---

# 31. Verifying the read

After success:

```text
RAM 0x17C00
```

should contain exactly the first 512 bytes of `disk.img`, which is Stage 1.

If Stage 1 has the normal BIOS boot signature:

```text
0x55 0xAA
```

those bytes are offsets 510 and 511.

Buffer:

```text
0x17C00 + 510 = 0x17DFE
```

Expected:

```text
RAM 0x17DFE = 0x55
RAM 0x17DFF = 0xAA
```

That is a direct proof that:

```text
our code
 ↓
ATA ports
 ↓
disk LBA 0
 ↓
512 bytes
 ↓
RAM
```

worked without BIOS assistance.

---

# 32. One-sector checklist

```text
[ ] QEMU disk is first IDE disk
[ ] wait until BSY clears
[ ] write Device register 0x1F6
[ ] allow device-select settling time
[ ] write Sector Count to 0x1F2
[ ] write LBA[7:0] to 0x1F3
[ ] write LBA[15:8] to 0x1F4
[ ] write LBA[23:16] to 0x1F5
[ ] LBA[27:24] is packed into 0x1F6
[ ] write 0x20 to 0x1F7
[ ] allow status-update time
[ ] poll until BSY = 0
[ ] fail if ERR = 1
[ ] fail if DF = 1
[ ] wait until DRQ = 1
[ ] read 256 words from 0x1F0
[ ] store 512 bytes in RAM
[ ] check final status
```

---

# 33. One-page reference

```text
PRIMARY ATA PIO — 28-BIT LBA


REQUEST
───────────────────────────────────────────────────────────────

0x1F1 W  Features
          optional command-specific parameters

0x1F2 W  Sector Count
          1–255 normally
          0 means 256 for READ SECTOR(S)

0x1F3 W  LBA Low
          LBA[7:0]

0x1F4 W  LBA Mid
          LBA[15:8]

0x1F5 W  LBA High
          LBA[23:16]

0x1F6 W  Device
          bit 7    obsolete / traditionally 1
          bit 6    LBA mode
          bit 5    obsolete / traditionally 1
          bit 4    DEV: 0 master, 1 slave
          bits 3:0 LBA[27:24]

0x1F7 W  Command
          0x20 = READ SECTOR(S)


RESPONSE
───────────────────────────────────────────────────────────────

0x1F7 R  Status
          bit 7 BSY
          bit 6 DRDY
          bit 5 DF
          bit 4 DSC / historical
          bit 3 DRQ
          bit 2 CORR / historical
          bit 1 IDX / historical
          bit 0 ERR

0x1F1 R  Error
          bit 7 BBK / ICRC
          bit 6 UNC
          bit 5 MC
          bit 4 IDNF
          bit 3 MCR
          bit 2 ABRT
          bit 1 TK0NF
          bit 0 AMNF

0x1F0 R  Data
          16-bit words
          256 words = 512 bytes


CONTROL
───────────────────────────────────────────────────────────────

0x3F6 R  Alternate Status
          status without acknowledging ATA interrupt

0x3F6 W  Device Control
          bit 7 HOB
          bit 3 obsolete
          bit 2 SRST
          bit 1 nIEN
          others reserved for this use


OUR LBA-0 REQUEST
───────────────────────────────────────────────────────────────

0x1F6 ← 11100000
0x1F2 ← 00000001
0x1F3 ← 00000000
0x1F4 ← 00000000
0x1F5 ← 00000000
0x1F7 ← 00100000

wait for:

BSY=0
ERR=0
DF=0
DRQ=1

then:

0x1F0 → 256 words → 512 bytes → RAM 95 KB
```

---

# 34. Historical names

```text
modern LBA name       older CHS name
────────────────────────────────────────
LBA Low               Sector Number
LBA Mid               Cylinder Low
LBA High              Cylinder High
Device                 Drive / Head
```

Abbreviations:

```text
ATA   = Advanced Technology Attachment
IDE   = Integrated Drive Electronics
PIO   = Programmed Input/Output
LBA   = Logical Block Address
CHS   = Cylinder / Head / Sector
DMA   = Direct Memory Access
IRQ   = Interrupt Request
DRQ   = Data Request
BSY   = Busy
DRDY  = Device Ready
DF    = Device Fault
ERR   = Error
SRST  = Software Reset
HOB   = High Order Byte
```

---

# 35. What this manual deliberately leaves for later

```text
48-bit LBA
READ SECTOR(S) EXT
DMA / bus-master IDE
SATA / AHCI
NVMe
ATAPI CD/DVD packet commands
multiple ATA channels
device 1 / slave
PCI IDE discovery
IRQ-driven completion
full timeout/recovery policy
full IDENTIFY parsing
filesystem parsing
```

None of those are required for our first direct disk read.

Our first storage stack is:

```text
x86 IN / OUT
    ↓
legacy primary ATA ports
    ↓
28-bit LBA task file
    ↓
PIO READ SECTOR(S)
    ↓
512 bytes
    ↓
RAM
```

---

# 36. Reference basis

This manual is based on the legacy ATA/ATAPI task-file model, cross-checked against:

- Linux `include/linux/ata.h`
- Linux libata legacy ATA handling
- QEMU system documentation for IDE drive attachment
- ATA/ATAPI command-set documentation
- classic Western Digital and Seagate ATA documentation
- OSDev ATA PIO documentation as a practical implementation reference

Where older and newer ATA revisions assign different meanings to obsolete or repurposed bits, this manual calls out the historical nature instead of pretending one revision's wording applies universally.
