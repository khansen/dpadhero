#!/bin/sh
packchr titlelogo.chr --nametable-base=0x0 --character-size=0x1000 --character-output=title-bg.chr --nametable-output=titlelogo.nam
packnam titlelogo.nam --width=32 --vram-address=0x2020 --output=titlelogo.dat
