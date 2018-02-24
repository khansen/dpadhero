/*
    This file is part of xm2btn.

    xm2btn is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    xm2btn is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with xm2btn.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "xm.h"

void convert_xm_to_btn(const struct xm *, const char *, FILE *);

static unsigned char note_to_type(unsigned char note)
{
    switch ((note - 1) % 12) {
        case 0: /* C = no modifier */
            return 0;
        case 1:
            break;
        case 2: /* D = down */
            return 3;
        case 3:
            break;
        case 4: /* E = right */
            return 1;
        case 5: /* F = up */
            return 4;
        case 6:
            break;
        case 7: /* G = left */
            return 2;
        case 8:
            break;
        case 9:
            break;
        case 10:
            break;
        case 11:
            break;
    }
    /*    assert(0); */
    return 0;
}

/**
  Converts the given \a xm to D-Pad hero button data; writes the 6502
  assembly language representation of the song to \a out.
*/
void convert_xm_to_btn(const struct xm *xm, const char *label_prefix, FILE *out)
{
    int pass;
    static const int chunk_count = 38;
    int chunk_length;
    int pos, length;
    int channel = 5;
    /* The 1st pass counts the number of items */
    /* The 2nd pass outputs the data */
    for (pass = 0; pass < 2; ++pass) {
        int order_pos;
        int delay = 0;
        if (pass == 1) {
            length = pos;
            chunk_length = length / chunk_count;
            assert(chunk_length < 256);
            fprintf(out, ".db $%.2X,$%.2X\n", xm->header.default_tempo + 1, chunk_length);
        }
        pos = 0;
        for (order_pos = 0; order_pos < xm->header.song_length; ++order_pos) {
            int row;
            const struct xm_pattern *pattern = &xm->patterns[xm->header.pattern_order_table[order_pos]];
            const struct xm_pattern_slot *slots = &pattern->data[channel];
            for (row = 0; row < pattern->row_count; ++row) {
                const struct xm_pattern_slot *bslot = &slots[row * xm->header.channel_count];
                const struct xm_pattern_slot *aslot = bslot + 1;
                if ((bslot->note != 0) || (aslot->note != 0)) {
                    unsigned char data = 0;
                    if (bslot->note != 0) {
                        data |= 0x80; /* B pressed */
                        data |= note_to_type(bslot->note);
                    }
                    if (aslot->note != 0) {
                        data |= 0x20; /* A pressed */
                        data |= note_to_type(aslot->note);
                    }
                    switch (pass) {
                        case 1:
                            fprintf(out, ".db $%.2X,$%.2X\n", delay, data);
                            break;
                    }
                    ++pos;
                    delay = 1;
                } else {
                    if (delay == 255) {
                        switch (pass) {
                            case 1:
                                /* Insert a row with no buttons, just to extend the delay */
                                fprintf(out, ".db $%.2X,$00\n", delay);
                                break;
                        }
                        ++pos;
                        delay = 0;
                    }
                    ++delay;
                }
            }
        }
    }
    /* End of button data */
    fprintf(out, ".db $00\n");
}

/*
; bit 7: B
; bit 6: B extended duration?
; bit 5: A
; bit 4: A extended duration?
; bit 3: unused
; bits 0..2: type (0=plain, 1=right, 2=left, 3=down, 4=up, 5=unused, 6=unused, 7=unused)
*/
