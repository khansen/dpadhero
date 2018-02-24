#!/bin/sh
packchr nespaper.chr --nametable-base=0x1 --character-size=0x1000 --character-output=nespaper-packed.chr --nametable-output=nespaper.nam
packnam nespaper.nam --width=24 --vram-address=0x2044 --output=nespaper.dat
