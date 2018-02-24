.include "common/ldc.h"
.include "common/joypad.h"
.include "common/ppu.h"
.include "common/sprite.h"
.include "mmc/mmc3.h"

.dataseg

.public selected_character

selected_character .byte

fading_character .byte
scroll_count .byte
menu_row .byte
menu_col .byte
selected_menu_item .byte

.extrn palette:byte
.extrn ppu:ppu_state
.extrn sprites:sprite_state
.extrn game_mode:byte

.codeseg

.public characterselect_init
.public characterselect_main
.public song_selected_main

.extrn nmi_off:proc
.extrn nmi_on:proc
.extrn screen_off:proc
.extrn screen_on:proc
.extrn reset_timers:proc
.extrn reset_sprites:proc
.extrn fill_nametable_0_0:proc
.extrn fill_nametable:proc
.extrn get_scroll_xy:proc
.extrn set_scroll_xy:proc
.extrn load_palette:proc
.extrn write_palette:proc
.extrn set_fade_range:proc
.extrn set_fade_delay:proc
.extrn start_fade_from_black:proc
.extrn start_fade_to_black:proc
.extrn start_timer:proc
.extrn start_zerotimer_with_callback:proc
.extrn set_timer_callback:proc
.extrn maybe_start_song:proc
.extrn start_sfx:proc
.extrn write_ppu_data_at:proc
.extrn next_sprite_index:proc
.extrn get_medal:proc
.extrn mixer_get_master_vol:proc
.extrn mixer_set_master_vol:proc

.ifdef MMC
.if MMC == 3
.extrn chr_banks:byte
.extrn swap_bank:proc
.endif
.endif

.extrn main_cycle:byte
.extrn joypad0_posedge:byte

.proc characterselect_init
    jsr screen_off
    jsr nmi_off
    jsr reset_timers
    jsr fill_nametable_0_0
    lda #0
    ldx #3
    jsr fill_nametable
    jsr reset_sprites

.ifdef MMC
.if MMC == 3
    lda #8
    sta chr_banks[0]
    lda #10
    sta chr_banks[1]
    lda #12
    sta chr_banks[2]
    lda #13
    sta chr_banks[3]
    lda #12
    sta chr_banks[4]
    lda #13
    sta chr_banks[5]
    lda #0
    jsr swap_bank
    lda #MMC3_MIRROR_V
    sta MMC3_MIRROR_REG
.endif
.endif

    lda #128
    tay
    jsr set_scroll_xy

    lda ppu.ctrl0
    ora #PPU_CTRL0_SPRITE_SIZE_8x16
    sta ppu.ctrl0

    ldcay @@interface_data
    jsr write_ppu_data_at

    ldcay default_palette
    jsr load_palette

    lda #0
    sta selected_character   ; default
    jsr highlight_character

    jsr draw_medals

    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jsr start_fade_from_black

    lda #5
    jsr maybe_start_song

    lda #4
    ldy #6
    jsr start_timer
    lda #<@@start_selecting
    ldy #>@@start_selecting
    jsr set_timer_callback

    lda #0
    sta main_cycle

    jsr screen_on
    jsr nmi_on
    rts

    @@start_selecting:
    lda #4
    sta main_cycle
    rts

.charmap "data/characterselect.tbl"

@@interface_data:
.incbin "data/sweet-select.dat"
.db $23,$E5,$02,$00,$00
.db $23,$ED,$02,$00,$00
.db $23,$F5,$02,$00,$00

.incbin "data/harder-select.dat"
.db $2F,$E1,$02,$55,$55
.db $2F,$E9,$02,$55,$55
.db $2F,$F1,$02,$55,$55

.incbin "data/feel-select.dat"
.db $23,$C5,$02,$AA,$AA
.db $23,$CD,$02,$AA,$AA
.db $23,$D5,$02,$AA,$AA

.incbin "data/swing-select.dat"
.db $2F,$C1,$02,$FF,$FF
.db $2F,$C9,$02,$FF,$FF
.db $2F,$D1,$02,$FF,$FF

; EOD
.db 0
.endp

default_palette:
.db $0f,$00,$10,$10 ; sweet
.db $0f,$00,$00,$10 ; harder
.db $0f,$00,$10,$10 ; feel
;.db $0f,$0F,$00,$10 ; swing
.db $0f,$00,$10,$10 ; swing
; sprites
.db $0f,$06,$16,$36 ; bronze
.db $0f,$00,$10,$20 ; silver
.db $0f,$17,$27,$37 ; gold
.db $0f,$20,$20,$20 ; menu

.proc characterselect_main
    jsr reset_sprites
    jsr draw_medals

    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START | JOYPAD_BUTTON_A)
    bne @@select_character

;    lda joypad0_posedge
;    and #JOYPAD_BUTTON_B
;    bne @@back

    jsr check_character_change
    rts

;    @@back:
;    lda #0
;    sta main_cycle
;    lda #0
;    ldy #31
;    jsr set_fade_range
;    jsr start_fade_to_black
;    lda #6
;    ldy #8
;    jsr start_timer
;    ldcay @@really_go_back
;    jsr set_timer_callback
;    rts
;    @@really_go_back:
;    lda #1
;    sta main_cycle
;    rts

    @@select_character:
    jsr reset_sprites ; kill the medals
    lda #0
    ldx #4
    jsr start_sfx

    lda #0
    sta fading_character
    lda #4
    jsr set_fade_delay
;    lda #<scroll_selected_character
;    ldy #>scroll_selected_character
    lda #<fade_next_character
    ldy #>fade_next_character
    jsr start_zerotimer_with_callback

    lda #0
    sta main_cycle
    rts
.endp

.proc draw_medals
    lda #0 ; song # (loop index)
    @@loop:
    pha
    jsr get_medal
    beq @@next ; nothing to do if no medal
    tax ; save medal
    pla ; song #
    pha
    tay
    lda @@sprite_data_offsets,y
    tay
    txa ; restore medal
    pha
  - lda @@sprite_data,y
    beq +
    jsr next_sprite_index
    tax
    lda @@sprite_data,y
    iny
    sta sprites._y,x
    lda @@sprite_data,y
    iny
    sta sprites.tile,x
    lda @@sprite_data,y
    iny
    sta sprites._x,x
    pla ; medal (1..3)
    pha
    sec
    sbc #1
    sta sprites.attr,x
    jmp -
  + pla ; pop medal
    @@next:
    pla ; pop song #
    clc
    adc #1
    cmp #4
    bne @@loop
    rts

    @@sprite_data_offsets:
    .db @@l0-@@sprite_data
    .db @@l1-@@sprite_data
    .db @@l2-@@sprite_data
    .db @@l3-@@sprite_data

    @@sprite_data:
    ; sweet
    @@l0:
    .db 82,$41,54+0
    .db 82,$43,54+8
    .db 82,$45,54+16
    .db 82+16,$47,54+0
    .db 82+16,$49,54+8
    .db 0
    ; harder
    @@l1:
    .db 82,$41,54+128+0
    .db 82,$43,54+128+8
    .db 82,$45,54+128+16
    .db 82+16,$47,54+128+0
    .db 82+16,$49,54+128+8
    .db 0
    ; feel
    @@l2:
    .db 82+112,$41,54+0
    .db 82+112,$43,54+8
    .db 82+112,$45,54+16
    .db 82+112+16,$47,54+0
    .db 82+112+16,$49,54+8
    .db 0
    ; swing
    @@l3:
    .db 82+112,$41,54+128+0
    .db 82+112,$43,54+128+8
    .db 82+112,$45,54+128+16
    .db 82+112+16,$47,54+128+0
    .db 82+112+16,$49,54+128+8
    .db 0
.endp

.proc fade_next_character
    @@again:
    lda fading_character
    cmp #4
    beq @@done_fading
    cmp selected_character
    bne @@fade_it
    inc fading_character
    jmp @@again

    @@fade_it:
    asl
    asl
    ora #3
    tay
    and #$FC
    jsr set_fade_range
    jsr start_fade_to_black

    inc fading_character

    lda #4
    ldy #4
    jsr start_timer
    lda #<fade_next_character
    ldy #>fade_next_character
    jsr set_timer_callback
    rts

    @@done_fading:
    ; set palette entries of non-selected characters to black
    ldy #0
  - cpy selected_character
    beq +
    tya
    pha
    asl
    asl
    tay
    lda #$0F
    sta palette+1,y
    sta palette+2,y
    sta palette+3,y
    pla
    tay
  + iny
    cpy #4
    bne -
    jsr write_palette

    lda #0
    sta scroll_count
    lda #<scroll_selected_character
    ldy #>scroll_selected_character
    jsr start_zerotimer_with_callback
    rts
.endp

; scrolls the selected character until he's centered on the screen
.proc scroll_selected_character
    lda selected_character
    asl
    tax
    jsr get_scroll_xy
    clc
    adc @@scroll_delta,x
    pha
    tya
    clc
    adc @@scroll_delta+1,x
    tay
    pla
    jsr set_scroll_xy

    inc scroll_count
    lda scroll_count
    cmp #64
    beq @@done_scrolling

    lda #<scroll_selected_character
    ldy #>scroll_selected_character
    jsr start_zerotimer_with_callback
    rts

    @@done_scrolling:
    lda #0
    sta selected_menu_item
    lda #12
    sta main_cycle
    rts

@@scroll_delta:
.db -1,-1
.db 1,-1
.db -1,1
.db 1,1
.endp

; calculate new character from input
.proc calculate_new_character
    lda joypad0_posedge
    and #JOYPAD_BUTTON_RIGHT
    beq +
    inc selected_character
  + lda joypad0_posedge
    and #JOYPAD_BUTTON_LEFT
    beq +
    dec selected_character
  + lda joypad0_posedge
    and #JOYPAD_BUTTON_DOWN
    beq +
    inc selected_character
    inc selected_character
  + lda joypad0_posedge
    and #JOYPAD_BUTTON_UP
    beq +
    dec selected_character
    dec selected_character
  + lda selected_character
    and #3
    sta selected_character
    rts
.endp

.proc check_character_change
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_LEFT | JOYPAD_BUTTON_RIGHT | JOYPAD_BUTTON_UP | JOYPAD_BUTTON_DOWN)
    bne +
    rts

  + lda selected_character
    pha
    jsr calculate_new_character
; de-highlight the previous character
    pla
    jsr dehighlight_character
; highlight the new character
    lda selected_character
    jsr highlight_character
; set updated palette
    jsr write_palette
; sfx
    lda #1
    ldx #4
    jsr start_sfx
    rts
.endp

.proc dehighlight_character
; A = index of character
    asl
    asl
    tay
    lda default_palette+1,y
    sta palette+1,y
    lda default_palette+2,y
    sta palette+2,y
    lda default_palette+3,y
    sta palette+3,y
    rts
.endp

.proc highlight_character
; A = index of character
    asl
    asl
    tay
    lda @@highlighted_palette+1,y
    sta palette+1,y
    lda @@highlighted_palette+2,y
    sta palette+2,y
    lda @@highlighted_palette+3,y
    sta palette+3,y
    rts

@@highlighted_palette:
.db $0f,$16,$27,$20 ; sweet
.db $0f,$2C,$27,$30 ; harder
.db $0f,$16,$27,$20 ; feel
;.db $0f,$02,$22,$32 ; swing
.db $0f,$16,$27,$20 ; swing
.endp

.proc song_selected_main
    jsr reset_sprites
    jsr draw_medal_limits
    jsr draw_song_selected_menu
    jsr check_song_selected_input
    rts
.endp

.proc draw_medal_limits
    ldy selected_character
    lda @@sprite_data_offsets,y
    tay
  - lda @@sprite_data,y
    bne +
    rts
  + jsr next_sprite_index
    tax
    lda @@sprite_data,y
    iny
    sta sprites.tile,x
    lda @@sprite_data,y
    iny
    sta sprites._y,x
    lda @@sprite_data,y
    iny
    sta sprites._x,x
    lda @@sprite_data,y
    iny
    sta sprites.attr,x
    jmp -
    @@sprite_data_offsets:
    .db @@l0-@@sprite_data
    .db @@l1-@@sprite_data
    .db @@l2-@@sprite_data
    .db @@l3-@@sprite_data
    @@sprite_data:
    ; ### horribly hard-coded, should use medal_score_table in main.asm
    ; sweet
    @@l0:
    ; harder
    @@l1:
    ; feel
    @@l2:
    .db $1B,16,104,2    ; 1
    .db $1D,16+16,104,1 ; 2
    .db $1F,16+32,104,0 ; 3
    .db $23,16,104+24,3 ; 5
    .db $19,16,104+32,3 ; 0
    .db $17,16,104+40,3 ; K
    .db $21,16+16,104+24,3 ; 4
    .db $19,16+16,104+32,3 ; 0
    .db $17,16+16,104+40,3 ; K
    .db $1F,16+32,104+24,3 ; 3
    .db $19,16+32,104+32,3 ; 0
    .db $17,16+32,104+40,3 ; K
    .db 0
    ; swing
    @@l3:
    .db $1B,16,104,2    ; 1
    .db $1D,16+16,104,1 ; 2
    .db $1F,16+32,104,0 ; 3
    .db $23,16,104+24,3 ; 5
    .db $19,16,104+32,3 ; 0
    .db $17,16,104+40,3 ; K
    .db $21,16+16,104+24,3 ; 4
    .db $23,16+16,104+32,3 ; 5
    .db $17,16+16,104+40,3 ; K
    .db $1F,16+32,104+24,3 ; 3
    .db $23,16+32,104+32,3 ; 5
    .db $17,16+32,104+40,3 ; K
    .db 0
.endp

.proc check_song_selected_input
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START | JOYPAD_BUTTON_A)
    bne @@select_menu_item

    lda joypad0_posedge
    and #(JOYPAD_BUTTON_UP | JOYPAD_BUTTON_DOWN)
    bne @@change_menu_item
    rts

    @@change_menu_item:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_UP
    bne @@prev_item
    ; next item
    lda selected_menu_item
    cmp #2
    bcs +
    inc selected_menu_item
    lda #1
    ldx #4
    jsr start_sfx
  + rts
    @@prev_item:
    lda selected_menu_item
    beq +
    dec selected_menu_item
    lda #1
    ldx #4
    jsr start_sfx
  + rts

    @@select_menu_item:
    lda selected_menu_item
    cmp #2
    beq + ; no need to play a fancy sound effect for BACK
    lda #0
    ldx #4
    jsr start_sfx
  + lda #0
    sta main_cycle

    ldy selected_menu_item
    lda @@action_delay,y
    ldy #8
    jsr start_timer
    lda selected_menu_item
    asl
    tay
    lda @@menu_item_handlers+0,y
    pha
    lda @@menu_item_handlers+1,y
    tay
    pla
    jsr set_timer_callback

    lda selected_menu_item
    cmp #2
    beq +
    ; start timer that fades out music
    lda #3
    ldy #3
    jsr start_timer
    ldcay @@fade_sound_step
    jsr set_timer_callback

  + lda #0
    ldy #31
    jsr set_fade_range
    jmp start_fade_to_black

    @@fade_sound_step:
    jsr mixer_get_master_vol
    sec
    sbc #$10
    jsr mixer_set_master_vol
    ora #0
    beq +
    lda #3
    ldy #4
    jsr start_timer
    ldcay @@fade_sound_step
    jsr set_timer_callback
  + rts

    @@play:
    lda #0
    sta game_mode
    lda #5
    sta main_cycle
    rts

    @@listen:
    lda #1
    sta game_mode
    lda #5
    sta main_cycle
    rts

    @@back:
    lda #3
    sta main_cycle
    rts

    @@action_delay:
    .db 22,22,6

    @@menu_item_handlers:
    .dw @@play
    .dw @@listen
    .dw @@back
.endp

; ### this code is copied&pasted from the in-game pause menu, consider generalizing
.proc draw_song_selected_menu
    lda #0
    sta menu_row
    sta menu_col
    tay
  - lda @@text_data,y
    bne +
    iny
    lda @@text_data,y
    bne ++
    rts
 ++ inc menu_row
    lda #0
    sta menu_col
    jmp -
  + jsr next_sprite_index
    tax
    lda @@text_data,y
    iny
    sta sprites.tile,x
    lda menu_row
    asl
    asl
    asl
    asl
    adc #168
    sta sprites._y,x
    lda selected_menu_item
    cmp menu_row
    beq +
    lda #1 ; silver
    jmp ++
  + lda #3
 ++ sta sprites.attr,x
    lda menu_col
    asl
    asl
    asl
    adc #104
    sta sprites._x,x
    inc menu_col
    jmp -
    @@text_data:
.charmap "data/songmenu.tbl"
.char " PLAY" : .db 0
.char "LISTEN" : .db 0
.char " BACK" : .db 0
.db 0
    rts
.endp

.end
