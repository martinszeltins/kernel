; -------------------------------------------------------------------------
; PT[6] - Stack (24 KB - 28 KB)
; -------------------------------------------------------------------------

Simple enough. I just need to go to PT[6] and fill the entry. PT lives at 108 KB and 1 entry is 8 bytes so I just need to move 108 KB + (8B * 6B) = 108 KB + 48 bytes = 110592 bytes + 48 bytes = 110640 bytes

So I _think_ I got the bytes right (I hope). Now all that is left is to figure out the address of 24 KB and the flags. Shouldn't be that hard... Let's see... 24 KB = 24576 or in binary 110000000000000 so that will be our RAM frame address. Good. But this is also where I need to be very careful. The format says 40 bits for the address AND the last 12 bits will ALWAYS be all 0s. Even if we map a HUGE address the last 12 bits will STILL be all 0s. And we do not need to put those 12 0s in ADR. The CPU will calculate the offset itself and instead the 12 bits can be used for flags. Nice! So we end up with 110 if we cut off the last 12 bits. Cool! But since PTE requires 40 bits for address we just pad it with zeros so it becomes: 0000000000000000000000000000000000000110 and that is our ADR bits.

So now we have the address: 0000000000000000000000000000000000000110 and we have the flags (present and r/w). We have all we need. The format is this:
| NX | PK | PK | PK | PK | IG | IG | IG | IG | IG | IG | IG |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR |ADR | R* | IG | IG | G  | PAT |  D  | A |PCD|PWT| U/S | R/W | P |

That is the binary format all 64 bits. It starts with bit 0 with the Present bit. and second bit is the r/w bit. those are our flags. we need to set them to 1 and 1. Good. Then there are a bunch of other flags and ignored bits (which we apparently do not need) and then the actual address of RAM for this page. We already have that - "0000000000000000000000000000000000000110". Good. And then there are some ignored bits and PK and NX bits which we do not need either - so just 0s. Easy enough. Lets try to put it together now.

000000000011 - flags
0000000000000000000000000000000000000110 - RAM frame address (padded to get 40 bits for address)
000000000000 - IG, PK, NX bits

Putting it all together we get: 0000000000000000000000000000000000000000000000000110000000000011
And we we split it in half to get 32 bits + 32 bits (since we are still in 32bit protected mode) then we get:

mov dword [110640], 00000000000000000110000000000011b           ; lower 32 bits of PT[6] entry
mov dword [110640 + 4], 00000000000000000000000000000000b       ; upper 32 bits

Here we go! Makes sense in my head!
