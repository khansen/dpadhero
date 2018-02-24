#!/bin/sh
packchr pokal.chr --nametable-base=0x1 --character-size=0x800 --character-output=pokal-packed.chr --nametable-output=pokal.nam
packnam pokal.nam --width=10 --vram-address=0x294B --output=pokal.dat
