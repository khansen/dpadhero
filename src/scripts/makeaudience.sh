#!/bin/sh
packchr audience.chr --nametable-base=0x90 --character-output=audience-packed.chr --nametable-output=audience.nam
packnam audience.nam --width=32 --vram-address=0x2120 --output=audience.dat
