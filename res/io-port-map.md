```bash
I/O PORT ADDRESS SPACE

0x0000
│
├─ 0x0000–0x000F   DMA controller #1
│
├─ 0x0010–0x001F   Legacy DMA / system miscellaneous
│
├─ 0x0020–0x0021   PIC #1 (master interrupt controller)
│
├─ 0x0022–0x003F   Reserved / chipset-specific / miscellaneous
│
├─ 0x0040–0x0043   PIT (programmable interval timer)
│
├─ 0x0044–0x005F   Timer-related / reserved / miscellaneous
│
├─ 0x0060          Keyboard controller data
├─ 0x0061          System control / speaker / misc
├─ 0x0062–0x0063   Miscellaneous / usually not important for us
├─ 0x0064          Keyboard controller status / command
├─ 0x0065–0x006F   Reserved / miscellaneous
│
├─ 0x0070          RTC / CMOS index, also NMI control
├─ 0x0071          RTC / CMOS data
├─ 0x0072–0x007F   Reserved / miscellaneous
│
├─ 0x0080          POST / delay / debug port
├─ 0x0081–0x008F   DMA page registers / legacy system ports
│
├─ 0x0090–0x0091   Miscellaneous system control
├─ 0x0092          System Control Port A
│                  (famously used for A20 and sometimes reset)
├─ 0x0093–0x009F   Reserved / miscellaneous
│
├─ 0x00A0–0x00A1   PIC #2 (slave interrupt controller)
├─ 0x00A2–0x00BF   Reserved / miscellaneous
│
├─ 0x00C0–0x00DF   DMA controller #2
│
├─ 0x00E0–0x00EF   Reserved / miscellaneous
│
├─ 0x00F0–0x00FF   FPU / coprocessor / legacy numeric hardware
│
├─ 0x0100–0x016F   Mostly unused / device-specific / nonstandard
│
├─ 0x0170–0x0177   Secondary ATA channel
│   ├─ 0x0170      Data
│   ├─ 0x0171      Error / Features
│   ├─ 0x0172      Sector Count
│   ├─ 0x0173      LBA Low
│   ├─ 0x0174      LBA Mid
│   ├─ 0x0175      LBA High
│   ├─ 0x0176      Drive / Head
│   └─ 0x0177      Status / Command
│
├─ 0x0178–0x01EF   Mostly unused / device-specific / legacy expansions
│
├─ 0x01F0–0x01F7   Primary ATA channel
│   ├─ 0x01F0      Data
│   ├─ 0x01F1      Error (read) / Features (write)
│   ├─ 0x01F2      Sector Count
│   ├─ 0x01F3      LBA Low
│   ├─ 0x01F4      LBA Mid
│   ├─ 0x01F5      LBA High
│   ├─ 0x01F6      Drive / Head
│   └─ 0x01F7      Status (read) / Command (write)
│
├─ 0x01F8–0x01FF   Reserved / miscellaneous
│
├─ 0x0200–0x0207   Game port / joystick
│
├─ 0x0208–0x021F   Reserved / miscellaneous
│
├─ 0x0220–0x022F   Sound Blaster compatible audio (common legacy range)
│
├─ 0x0230–0x0277   Device-specific / often unused
│
├─ 0x0278–0x027F   LPT2 parallel port
│
├─ 0x0280–0x02DF   Device-specific / often unused
│
├─ 0x02E8–0x02EF   COM4 serial port
│
├─ 0x02F8–0x02FF   COM2 serial port
│
├─ 0x0300–0x031F   Device-specific / network cards / expansion devices
│
├─ 0x0330–0x0331   MPU-401 MIDI
│
├─ 0x0332–0x0377   Device-specific / miscellaneous legacy hardware
│
├─ 0x0378–0x037F   LPT1 parallel port
│
├─ 0x0380–0x0387   Reserved / device-specific
│
├─ 0x0388–0x038B   FM synthesizer / AdLib / OPL-style audio
│
├─ 0x038C–0x03AF   Device-specific / miscellaneous
│
├─ 0x03B0–0x03BF   Monochrome display adapter / Hercules
│
├─ 0x03C0–0x03DF   VGA / video controller registers
│   ├─ 0x03C0–0x03CF   VGA attribute / sequencer / graphics controller
│   ├─ 0x03D0–0x03DF   VGA CRT controller / color display registers
│
├─ 0x03E0–0x03EF   Reserved / device-specific
│
├─ 0x03F0–0x03F7   Floppy disk controller area
│   ├─ 0x03F2      Floppy Digital Output Register
│   ├─ 0x03F4      Floppy Main Status Register
│   ├─ 0x03F5      Floppy Data Register
│   ├─ 0x03F6      Primary ATA alternate status / device control
│   └─ 0x03F7      Floppy Digital Input / config related
│
├─ 0x03F8–0x03FF   COM1 serial port
│
├─ 0x0400–0x04FF   Generally open / device-specific / board-specific
│
├─ 0x0500–0x0BFF   Mostly device-specific / expansion / often unused
│
├─ 0x0C00–0x0CF7   Device-specific / chipset-specific
│
├─ 0x0CF8–0x0CFF   PCI configuration mechanism #1
│   ├─ 0x0CF8      PCI config address
│   ├─ 0x0CFC      PCI config data
│   └─ 0x0CF9      Reset control on many systems
│
├─ 0x0D00–0xFFFF   Mostly chipset-specific / motherboard-specific /
│                  PCI-assigned / ACPI-related / vendor-specific /
│                  or unused depending on machine
│
0xFFFF
````
