```asm
mov dx, 0x1F6 ; DX contains I/O port
mov al, 0xE0  ; al contains value to write to that port
out dx, al    ; out the port DX write value in AL
````


# Ports

```text
PORT      WRITE                         READ
────────────────────────────────────────────────────

0x1F0     Data → disk                   Data ← disk
0x1F1     Features                      Error
0x1F2     Sector Count                  Sector Count
0x1F3     LBA bits 0–7                  LBA bits 0–7
0x1F4     LBA bits 8–15                 LBA bits 8–15
0x1F5     LBA bits 16–23                LBA bits 16–23
0x1F6     Device + LBA bits 24–27       Device
0x1F7     Command                       Status

0x3F6     Device Control                Alternate Status
```

---

# LBA format

A 28-bit sector number is split like this:

```text
27 26 25 24   23 ........ 16    15 ........ 8    7 ........ 0
┌───────────┬─────────────────┬────────────────┬───────────────┐
│ 0x1F6     │     0x1F5       │     0x1F4      │     0x1F3     │
│ bits 3–0  │                 │                │               │
└───────────┴─────────────────┴────────────────┴───────────────┘
```

For LBA 0:

```text
0x1F3 = 0
0x1F4 = 0
0x1F5 = 0
0x1F6 low 4 bits = 0
```

---

# Port 0x1F6 format

```text
bit:     7      6      5      4       3       2       1       0
      ┌──────┬──────┬──────┬──────┬───────┬───────┬───────┬───────┐
      │ OBS  │ LBA  │ OBS  │ DEV  │ LBA27 │ LBA26 │ LBA25 │ LBA24 │
      └──────┴──────┴──────┴──────┴───────┴───────┴───────┴───────┘
```

```text
bit 7 = obsolete, traditionally written as 1
bit 6 = 1 → use LBA addressing
bit 5 = obsolete, traditionally written as 1
bit 4 = 0 → device 0 / master
bits 3–0 = top 4 bits of LBA
```

For our LBA 0 read:

```text
1110 0000
=
0xE0
```

---

# Port 0x1F7 — Command

When WRITING:

```text
0x1F7 = Command
```

Important examples:

```text
0x20 = READ SECTOR(S)
0x30 = WRITE SECTOR(S)
0xEC = IDENTIFY DEVICE
0xE7 = FLUSH CACHE
```

Our command:

```text
0x20
```

---

# Port 0x1F7 — Status

When READING:

```text
bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │ BSY  │ DRDY │  DF  │ DSC  │ DRQ  │ CORR │ IDX  │ ERR  │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

For our reader, only remember:

```text
BSY bit 7 = 1 → disk is busy
DF  bit 5 = 1 → device fault
DRQ bit 3 = 1 → data is ready
ERR bit 0 = 1 → error
```

We want:

```text
BSY = 0
DF  = 0
ERR = 0
DRQ = 1
```

---

# One-sector read request

We want:

```text
device = 0
LBA    = 0
count  = 1
```

So we send:

```text
0x1F6 ← 0xE0     device 0 + LBA mode + LBA[27:24]=0
0x1F2 ← 1        one sector
0x1F3 ← 0        LBA[7:0]
0x1F4 ← 0        LBA[15:8]
0x1F5 ← 0        LBA[23:16]
0x1F7 ← 0x20     READ SECTOR(S)
```

Then:

```text
poll 0x1F7
↓
wait until BSY=0 and DRQ=1
↓
fail if ERR=1 or DF=1
↓
read data from 0x1F0
```

---

# Reading the 512 bytes

Port `0x1F0` gives us 16 bits at a time:

```text
16 bits = 2 bytes
```

One sector:

```text
512 bytes
```

Therefore:

```text
512 / 2 = 256 reads
```

Conceptually:

```asm
mov dx, 0x1F0
mov rcx, 256

.read:
    in ax, dx
    mov [rdi], ax
    add rdi, 2

    dec rcx
    jnz .read
```

---

# Tiny complete flow

```text
1. Wait until BSY = 0

2. 0x1F6 ← 0xE0
   select device 0 + LBA mode

3. 0x1F2 ← 1
   one sector

4. 0x1F3 ← 0
   0x1F4 ← 0
   0x1F5 ← 0
   LBA = 0

5. 0x1F7 ← 0x20
   READ SECTOR(S)

6. Poll 0x1F7 until:
   BSY = 0
   DRQ = 1
   ERR = 0
   DF  = 0

7. Read 256 words from 0x1F0

8. Store those 512 bytes in RAM
```

---

# Mental model

```text
REQUEST
─────────────────────────────

0x1F6  device + LBA mode
0x1F2  sector count
0x1F3  LBA low
0x1F4  LBA middle
0x1F5  LBA high
0x1F7  command

          ↓

        DISK

          ↓

RESPONSE
─────────────────────────────

0x1F7  status
0x1F1  error details
0x1F0  actual sector data
```

