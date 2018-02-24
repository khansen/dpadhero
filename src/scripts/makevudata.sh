#!/bin/sh
packchr vu.chr --nametable-base=0x60 --character-output=vu-packed.chr --nametable-output=vu.nam
packnam vu.nam --width=8 --vram-address=0x2257 --output=vu.dat
