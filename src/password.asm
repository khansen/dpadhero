.include "common/ldc.h"
.include "common/joypad.h"
.include "common/sprite.h"
.include "common/ppu.h"

.dataseg

; current column of the password that's being edited
current_column .db

; password is 8 button combos long, each is stored in 4 bits
password_input .db[4]

password_data_v1 .db[3]

password_data_v2 .db[3]

tmp .db

.codeseg

.extrn screen_off:proc
.extrn screen_on:proc
.extrn nmi_off:proc
.extrn nmi_on:proc
.extrn fill_nametable_0_0:proc
.extrn reset_sprites:proc
.extrn set_scroll_xy:proc
.extrn write_ppu_data_at:proc
.extrn load_palette:proc
.extrn set_fade_range:proc
.extrn set_fade_delay:proc
.extrn start_fade_from_black:proc
.extrn next_sprite_index:proc
.extrn begin_ppu_string:proc
.extrn put_ppu_string_byte:proc
.extrn end_ppu_string:proc

.extrn frame_count:byte
.extrn joypad0_posedge:byte
.extrn joypad0:byte
.extrn main_cycle:byte
.extrn ppu:ppu_state
.extrn sprites:sprite_state

.ifdef MMC
.if MMC == 3
.extrn chr_banks:byte
.endif
.endif

.public enter_password_init
.public enter_password_main

.proc enter_password_init
    jsr screen_off
    jsr nmi_off
    jsr fill_nametable_0_0
    jsr reset_sprites
    lda #0
    tay
    jsr set_scroll_xy
    lda ppu.ctrl0
    ora #PPU_CTRL0_SPRITE_SIZE_8x16
    sta ppu.ctrl0

.ifdef MMC
.if MMC == 3
    lda #20
    sta chr_banks[0]
    lda #22
    sta chr_banks[1]
    lda #24
    sta chr_banks[2]
    lda #25
    sta chr_banks[3]
    lda #26
    sta chr_banks[4]
    lda #27
    sta chr_banks[5]
.endif
.endif

    ldcay @@interface_data
    jsr write_ppu_data_at

    ldcay @@palette
    jsr load_palette
    lda #0
    ldy #31
    jsr set_fade_range
    lda #6
    jsr set_fade_delay
    jsr start_fade_from_black

    lda #0
    sta current_column
    sta password_input+0
    sta password_input+1
    sta password_input+2
    sta password_input+3

    inc main_cycle
    jsr screen_on
    jsr nmi_on
    rts

@@interface_data:
.charmap "data/title.tbl"
.db $20,$C5,22
.char "ENTER PASSWORD, PLEASE"
; the underscores
.db $21,$C8,$10,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02
; EOD
.db 0

@@palette:
.db $0f,$06,$10,$27
.db $0f,$00,$10,$00
.db $0f,$00,$10,$00
.db $0f,$00,$10,$00
.db $0f,$10,$10,$20
.db $0f,$00,$10,$00
.db $0f,$00,$10,$00
.db $0f,$00,$10,$00
.endp

.proc enter_password_main
    jsr reset_sprites
    jsr check_buttons
    jsr draw_cursor
    rts
.endp

.proc check_buttons
    lda joypad0_posedge
    and #JOYPAD_BUTTON_START
    beq +
    jmp @@validate
  + lda joypad0_posedge
    and #JOYPAD_BUTTON_SELECT
    beq +
    jmp @@back_up
  + lda joypad0_posedge
    and #(JOYPAD_BUTTON_A | JOYPAD_BUTTON_B)
    beq +
    jmp @@enter_combo
  + lda joypad0
    and #$0F
    bne @@highlight_arrow
    rts

    @@highlight_arrow:
    ldy #0
  - lsr
    bcs +
    iny
    bne -
  + jsr next_sprite_index
    tax
    lda @@arrow_attr_table,y
    sta sprites.attr,x
    lda @@arrow_tile_table,y
    sta sprites.tile,x
    lda #96-2
    sta sprites._y,x
    lda current_column
    asl
    asl
    asl
    asl
    adc #64+3
    sta sprites._x,x
    rts

    @@arrow_attr_table:
    .db $00,$40,$00,$80
    @@arrow_tile_table:
    .db $05,$05,$07,$07

    @@enter_combo:
    ; calculate the button combo index (0..9)
    ldy #0
    lda joypad0
    and #$0F
    beq +
    iny
  - lsr
    bcs +
    iny
    bne -
  + tya
    clc
    lda joypad0
    and #JOYPAD_BUTTON_B
    bne +
    sec
  + tya
    rol ; A contains the button combo (0..9)
    pha
; print upper half of button
    ldy #$21
    lda current_column
    asl
    adc #$E8
    ldx #$02
    jsr begin_ppu_string
    pla
    pha
    and #1
    asl
    adc #3
    jsr put_ppu_string_byte
    clc
    adc #1
    jsr put_ppu_string_byte
    jsr end_ppu_string
; print lower half of button
    ldy #$22
    lda current_column
    asl
    adc #$08
    ldx #$02
    jsr begin_ppu_string
    pla
    pha
    and #1
    asl
    adc #$13
    jsr put_ppu_string_byte
    clc
    adc #1
    jsr put_ppu_string_byte
    jsr end_ppu_string
; print upper half of arrow (if any)
    ldy #$21
    lda current_column
    asl
    adc #$88
    ldx #$02
    jsr begin_ppu_string
    pla
    pha
    and #$E
    beq +
    adc #5
  + jsr put_ppu_string_byte
    ora #0
    beq +
    clc
    adc #1
  + jsr put_ppu_string_byte
    jsr end_ppu_string
; print lower half of arrow
    ldy #$21
    lda current_column
    asl
    adc #$A8
    ldx #$02
    jsr begin_ppu_string
    pla
    pha
    and #$E
    beq +
    adc #$15
  + jsr put_ppu_string_byte
    ora #0
    beq +
    clc
    adc #1
  + jsr put_ppu_string_byte
    jsr end_ppu_string

    ; store the button combo+1
    lda current_column
    lsr
    tay
    lda password_input,y
    bcs +
    and #$0F ; even columns stored in upper 4 bits
    bcc ++
  + and #$F0 ; odd columns stored in lower 4 bits
 ++ sta password_input,y
    pla
    php
    clc
    adc #1
    plp
    bcs +
    asl
    asl
    asl
    asl
  + ora password_input,y
    sta password_input,y

    ; advance the cursor
    lda current_column
    clc
    adc #1
    and #7
    sta current_column
    rts

    @@back_up:
    lda current_column
    sec
    sbc #1
    and #7
    sta current_column
    rts

    @@validate:
    ; step 1 is to convert each input "character" (button combo) to a 3-bit value
    ldy #0
  - tya
    lsr
    tax
    lda password_input,x
    bcs +
    lsr
    lsr
    lsr
    lsr
  + and #$0F
    bne +
    jmp @@error ; if no combo has been entered, the password is definitely not valid
  + sec
    sbc #1
    jsr find_bits_for_combo
    bcs +
    jmp @@error
    ; shift the 3 bits into password_data_v1
  + ror
    ror
    ror
    rol password_data_v1+2
    rol password_data_v1+1
    rol password_data_v1+0
    ; next column
    iny
    cpy #8
    bne -

; rearrange the bits, storing the result in password_data_v2
    ldx #0
  - lda @@rearranged_bit_index_table,x
    lsr
    lsr
    lsr
    tay
    lda password_data_v1,y
    pha
    lda @@rearranged_bit_index_table,x
    and #7
    eor #7
    tay
    pla
 -- lsr
    dey
    bpl --
    rol password_data_v2+2
    rol password_data_v2+1
    rol password_data_v2+0
    inx
    cpx #24
    bne -

    ; apply the XOR
    lda password_data_v2+2
    and #$0F
    pha
    eor password_data_v2+0
    sta password_data_v2+0
    pla
    pha
    eor password_data_v2+1
    sta password_data_v2+1
    pla
    asl
    asl
    asl
    asl
    pha
    eor password_data_v2+0
    sta password_data_v2+0
    pla
    pha
    eor password_data_v2+1
    sta password_data_v2+1
    pla
    eor password_data_v2+2
    sta password_data_v2+2

    ; finally, check that the two halves of the data (10+10 bits) are identical
    ; xxxx xxxx xxyy yyyy yyyy
    lda password_data_v2+0
    and #$FC
    sta tmp
    lda password_data_v2+1
    asl
    asl
    eor tmp
    bne @@error
    lda password_data_v2+0
    and #$03
    sta tmp
    lda password_data_v2+1
    rol
    rol tmp
    rol tmp
    lda password_data_v2+2
    lsr
    lsr
    lsr
    lsr
    eor tmp
    bne @@error

    ; yay, the password is valid!
    jmp reset
    rts

    @@error:
    rts

    @@rearranged_bit_index_table:
; source: VSPMJGDA WTQNKHEB XUROLIFC
; target: ABCDEFGH IJKLMNOP QRSTUVWX
    .db 7,15,23
    .db 6,14,22
    .db 5,13,21
    .db 4,12,20
    .db 3,11,19
    .db 2,10,18
    .db 1,9,17
    .db 0,8,16
.endp

; A = combo (0..9)
; Y = column (0..7)
.proc find_bits_for_combo
    pha
    tya
    asl
    asl
    asl
    tax ; column * 8
    pla
  - cmp bits_to_combo_map,x
    bne +
    lda bits_to_combo_map,x
    sec ; found
    rts
  + pha
    inx
    txa
    and #7
    beq +
    pla
    jmp -
  + pla
    clc ; not found
    rts
.endp

.proc draw_cursor
    lda frame_count
    and #16
    beq @@draw
    rts
    @@draw:
    jsr next_sprite_index
    tax
    lda #0
    sta sprites.attr,x
    lda #$01
    sta sprites.tile,x
    lda #96
    sta sprites._y,x
    lda current_column
    asl
    asl
    asl
    asl
    adc #64
    pha
    sta sprites._x,x
    jsr next_sprite_index
    tax
    lda #0
    sta sprites.attr,x
    lda #$03
    sta sprites.tile,x
    lda #96
    sta sprites._y,x
    pla
    clc
    adc #8
    sta sprites._x,x
    rts
.endp

; - medal for each song: none, bronze, silver, gold (2 bits)
;   - 4 songs, 2*4 = 8 bits
; - difficulty level: easy, normal, hard, insane (2 bits)
; - total: 10 bits (1024 valid passwords)

; 10 different key combos
; - only 8 different combos are possible for a given column
; password length: 8 combos (?)
; - need to shuffle around the bits so it's not obvious
; - combos are assigned different values for different columns
;   - so that even if the password data is all 0s, it's not
;     going to look like that (e.g. the password won't just be
;     A A A A A A A A)
; - use checksum
;   - since the password is so short, how about just storing
;     the whole password twice?
; - use the frame counter as "random number"

; unencoded bits (10 bits total)
; xx xx xx xx xx

; interleave the bits so that related information is not stored in consecutive bits
; duplicate the bits (with separate interleaving) (20 bits total)

; add the random nibble (24 bits total)
; XOR the other nibbles by the random nibble
; xxxx xxxx xxxx xxxx xxxx xxxx

; split into 3-bit groups (8)
; xxx xxx xxx xxx xxx xxx xxx xxx

; consult the table to determine which button combo to display
bits_to_combo_map:
.db 0,1,3,2,4,7,5,6 ; column 0
.db 2,3,1,0,5,9,8,4 ; column 1
.db 1,5,7,2,4,0,3,6 ; column 2
.db 9,2,6,5,1,8,7,0 ; column 3
.db 4,0,1,3,2,9,5,6 ; column 4
.db 6,9,4,0,5,3,1,2 ; column 5
.db 3,1,2,9,8,5,7,0 ; column 6
.db 7,4,3,6,0,8,9,1 ; column 7

; to decode the password:
; loop 8 times
;   scan the row in the table to find the value (0..7) that the combo corresponds to
;   if it's not found, the password is definitely not valid -- reject
;   else, store the 3-bit value

; now we have the 3-bit groups
; xxx xxx xxx xxx xxx xxx xxx xxx

; extract the XOR value from the 4 LSB
; XOR the other nibbles
; de-interleave the two sets of 10 bits
; if they are not equal, reject
; else, accept, and load the data from the password

.end
