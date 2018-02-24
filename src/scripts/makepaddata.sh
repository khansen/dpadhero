#!/bin/sh
packchr dpad2.chr --nametable-base=16 --character-output=dpad-packed.chr --nametable-output=dpad.nam
packnam dpad.nam --width=20 --vram-address=0x2241 --output=dpad.dat
