#!/bin/sh
packchr sweet-select.chr --null-tile=0 --nametable-base=1 --character-output=sweet-select-packed.chr --nametable-output=sweet-select.nam
packnam sweet-select.nam --width=8 --vram-address=0x2254 --output=sweet-select.dat
packchr harder-select.chr --null-tile=0 --nametable-base=55 --character-output=harder-select-packed.chr --nametable-output=harder-select.nam
packnam harder-select.nam --width=8 --vram-address=0x2E44 --output=harder-select.dat
packchr feel-select.chr --null-tile=0 --nametable-base=106 --character-output=feel-select-packed.chr --nametable-output=feel-select.nam
packnam feel-select.nam --width=8 --vram-address=0x2054 --output=feel-select.dat
packchr swing-select.chr --null-tile=0 --nametable-base=155 --character-output=swing-select-packed.chr --nametable-output=swing-select.nam
packnam swing-select.nam --width=8 --vram-address=0x2C44 --output=swing-select.dat
