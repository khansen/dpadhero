.include "common/ldc.h"
.include "common/sprite.h"
.include "common/ptr.h"
.include "common/fixedpoint.h"
.include "common/ppu.h"
.include "common/joypad.h"
.include "mmc/mmc3.h"

.dataseg

.extrn selected_character:byte
.extrn ppu_buffer:byte
.extrn ppu_buffer_offset:byte
.extrn sprites:sprite_state
.extrn ppu:ppu_state
.extrn frame_count:db
.extrn joypad0:db
.extrn joypad0_posedge:db
.extrn ppu_buffer:db
.extrn ppu_buffer_offset:db

.public game_mode:byte
.public medal_status:byte

; 0 = play, 1 = listen, 2 = demo
game_mode .db

; Holds the state of a falling button.
.struc button
state .db    ; modifiers (bit 2..0), button (bit 3)
pos .fp_8_8  ; vertical position
duration .db ; number of rows it lasts
next .db     ; next button on linked list
.ends

; array of buttons, used to populate the linked list
MAX_BUTTONS .equ 32
buttons .button[MAX_BUTTONS]

; linked lists
free_buttons_list .db
active_buttons_head .db
active_buttons_tail .db
hit_buttons_head .db
hit_buttons_tail .db
missed_buttons_head .db
missed_buttons_tail .db

; the speed at which buttons are falling (in pixels per frame)
button_speed .fp_8_8
button_data_speed .db
button_data_timer .dw
button_data_chunk_length .db

begin_song_timer .dw

button_song .db

medal_status .db ; 2 bits per song
score .db[3]
top_scores .dd[4]
points_level .db
stat_changed .db
current_streak .dw
longest_streak .dw
missed_count .dw
hit_count .dw
error_count .dw
vu_level .db
progress_level .db
progress_countdown .db

text_scroller_data .ptr
text_scroller_offset .db
text_scroller_timer .db

audience_status .db

selected_menu_item .db

; temp variables
tmp .db
joybits .db
prev .db
menu_row .db
menu_col .db

; division-related
; ### move to its own file
AC0 .db  ; initial dividend & resulting quotient
AC1 .db
AC2 .db
XTND0 .db  ; remainder
XTND1 .db
XTND2 .db
AUX0 .db  ; divisor
AUX1 .db
AUX2 .db
TMP0 .db
Count .db

.dataseg zeropage

; Pointer to the data that describes buttons+timings
button_data .ptr

.codeseg

.extrn frame_count:byte
.extrn main_cycle:byte
.extrn nmi_off:proc
.extrn nmi_on:proc
.extrn load_palette:proc
.extrn start_fade_from_black:proc
.extrn screen_off:proc
.extrn screen_on:proc
.extrn reset_timers:proc
.extrn write_ppu_data_at:proc
.extrn reset_sprites:proc
.extrn next_sprite_index:proc
.extrn start_timer:proc
.extrn set_timer_callback:proc
.extrn start_zerotimer_with_callback:proc
.extrn fill_all_nametables:proc
.extrn get_scroll_xy:proc
.extrn set_scroll_xy:proc
.extrn set_fade_range:proc
.extrn set_fade_delay:proc
.extrn start_fade_to_black:proc
.extrn fade_out_step:proc
.extrn fade_in_step:proc
.extrn mixer_get_muted_channels:proc
.extrn mixer_set_muted_channels:proc
.extrn swap_bank:proc
.extrn begin_ppu_string:proc
.extrn end_ppu_string:proc
.extrn put_ppu_string_byte:proc
.extrn start_song:proc
.extrn start_sfx:proc
.extrn pause_music:proc
.extrn unpause_music:proc
.extrn bitmasktable:label

.extrn sweet_button_data:label
.extrn harder_button_data:label
.extrn feel_button_data:label
.extrn swing_button_data:label

.extrn MULTIPLY:label
.extrn PROD:label
.extrn MULR:label
.extrn MULND:label

.ifdef MMC
.if MMC == 3
.extrn chr_banks:byte
.endif
.endif

.public init

.public game_init
.public game_main
.public game_paused_main
.public game_done_main
.public game_stats_main
.public get_medal

.proc init
    lda #0
    jsr swap_bank
    lda #1
    sta main_cycle
    rts
.endp

.proc game_init
    jsr screen_off
    jsr nmi_off
    jsr reset_timers
    lda #0
    jsr fill_all_nametables
    lda #0
    tay
    jsr set_scroll_xy
    jsr reset_sprites

    lda #0
    jsr start_song ; mute

.ifdef MMC
.if MMC == 3
    lda #14
    sta chr_banks[0]
    lda #16
    sta chr_banks[1]
    lda #18
    sta chr_banks[2]
    lda #19
    sta chr_banks[3]
    lda #20
    sta chr_banks[4]
    lda #21
    sta chr_banks[5]
.endif
.endif

    ldcay @@interface_data
    jsr write_ppu_data_at

    ldcay @@palette
    jsr load_palette

    ; initialize linked lists
    lda #$FF
    sta active_buttons_head
    sta active_buttons_tail
    sta hit_buttons_head
    sta hit_buttons_tail
    sta missed_buttons_head
    sta missed_buttons_tail
    ldx #0
    stx free_buttons_list
  - txa
    clc
    adc #sizeof button
    sta buttons.next,x
    tax
    cpx #(sizeof button * (MAX_BUTTONS-1))
    bne -
    lda #$FF
    sta buttons.next,x

    ; reset stats
    lda #0
    sta score+0
    sta score+1
    sta score+2
    sta points_level
    sta current_streak+0
    sta current_streak+1
    sta longest_streak+0
    sta longest_streak+1
    sta missed_count+0
    sta missed_count+1
    sta hit_count+0
    sta hit_count+1
    sta error_count+0
    sta error_count+1
    sta vu_level
    sta progress_level
    sta audience_status

    ; initialize button data
    lda selected_character
;    lda #2
    asl
    asl
    asl
    tay
    lda button_data_table+1,y
    sta button_song
    lda button_data_table+2,y
    sta button_speed.int
    lda button_data_table+3,y
    sta button_speed.frac
    lda button_data_table+4,y
    pha
    lda button_data_table+6,y
    sta button_data.lo
    lda button_data_table+7,y
    sta button_data.hi
    lda button_data_table+0,y
    jsr swap_bank

    jsr fetch_button_data_byte
    sta button_data_speed
    jsr fetch_button_data_byte
    sta button_data_chunk_length
    sta progress_countdown

    ; start the button data processing
    jsr fetch_button_data_byte ; initial delay
    clc
    adc #1
    jsr set_button_data_timer

    lda #0
    jsr mixer_set_muted_channels
    ; the song is started later, to be in sync with the button data
    ; ### for the final version we can prepend empty rows in the song
    pla
    jsr set_begin_song_timer

    lda selected_character
    asl
    tay
    lda text_scroller_data_table+0,y
    sta text_scroller_data.lo
    lda text_scroller_data_table+1,y
    sta text_scroller_data.hi
    lda #0
    sta text_scroller_offset
    lda #7*7
    sta text_scroller_timer

    lda ppu.ctrl0
    ora #PPU_CTRL0_SPRITE_SIZE_8x16
    sta ppu.ctrl0

    jsr print_top_score

    inc main_cycle

    jsr screen_on
    jsr nmi_on

    lda #0
    ldy #31
    jsr set_fade_range
    lda #5
    jsr set_fade_delay
    jmp start_fade_from_black

@@palette:
; bg
.db $0f,$06,$00,$10 ; pad & VU
.db $0f,$16,$27,$17 ; audience
.db $0f,$17,$1B,$10 ; score, progress, scroller
.db $0f,$1C,$00,$10 ; d-pad hero logo
; sprites
.db $0f,$06,$10,$30 ; button
.db $0f,$08,$28,$2A ; joypad indicator, points level indicator
.db $0f,$20,$20,$20 ; pause menu
.db $0f,$20,$20,$20 ; pause menu

@@interface_data:
.incbin "data/audience.dat"
.incbin "data/dpad.dat"
.incbin "data/vu.dat"
; score
.db $20,$4C,$01,$02
.db $20,$4D,$46,$D0 ; score placeholder
.db $20,$56,$03,$03,$04,$05 ; TOP
.db $20,$59,$46,$D0 ; score placeholder
; d-pad hero logo
.db $20,$43,$06,$53,$54,$55,$56,$57,$58
.db $20,$63,$06,$59,$5A,$5B,$5C,$5D,$5E
.db $20,$83,$06,$81,$82,$83,$84,$85,$86
.db $20,$A4,$05,$87,$88,$89,$8A,$8B
; progress indicator
.db $20,$8C,$53,$0E
.db $20,$AC,$53,$0F
; attribute table
.db $23,$C0,$43,$FF
.db $23,$C3,$45,$AA
.db $23,$C8,$43,$FF
.db $23,$CB,$45,$AA
.db $23,$D0,$50,$55
.db $23,$E0,$48,$05
.db $23,$F0,$48,$A0
.db 0
.endp

.proc set_button_data_timer
    sta button_data_timer+0
    lda button_data_speed
    sta button_data_timer+1
    rts
.endp

.proc set_begin_song_timer
    sta begin_song_timer+0
    lda button_data_speed
    sta begin_song_timer+1
   rts
.endp

.proc maybe_begin_song
    lda begin_song_timer+0
    ora begin_song_timer+1
    bne +
    rts
  + dec begin_song_timer+1
    beq +
    rts
  + dec begin_song_timer+0
    beq +
    lda button_data_speed
    sta begin_song_timer+1
    rts
    ; turn on the sound channel(s)
  + jsr mixer_get_muted_channels
    and #$FC
    jsr mixer_set_muted_channels
    lda button_song
    jmp start_song
.endp

; Puts sprites that show which of the joypad buttons are pressed.
.proc draw_pressed_buttons
    lda game_mode
    beq + ; only draw buttons if we're in play mode
    rts
  + ldy #7
    @@loop:
    lda bitmasktable,y
    and joypad0
    beq @@next
    jsr next_sprite_index
    tax
    lda @@sprite_tile,y
    sta sprites.tile,x
    lda @@sprite_y,y
    sta sprites._y,x
    lda @@sprite_x,y
    sta sprites._x,x
    lda #1
    sta sprites.attr,x
    @@next:
    dey
    bpl @@loop
    rts
@@sprite_tile:
.db $21,$23,$25,$27,$29,$29,$2B,$2B
@@sprite_x:
.db 44,22,32,32,88,68,116,137
@@sprite_y:
.db 176,176,186,168,185,185,184,184
.endp

.proc game_main
    jsr reset_sprites
    jsr draw_pressed_buttons
    jsr maybe_begin_song
    jsr maybe_load_buttons
    jsr process_active_buttons
    jsr process_hit_buttons
    jsr process_missed_buttons
    jsr update_score_displays
    jsr update_progress_display
    jsr draw_vu_pin
    jsr draw_points_level_indicator
    jsr update_text_scroller
    jsr update_audience
    jsr check_pause
    jsr check_if_done
; turn on for dynamic "profiling" (the screen goes black when processing is done)
.if 0
    lda ppu.ctrl1
    and #~PPU_CTRL1_BG_VISIBLE
    sta $2001
.endif
    rts
.endp

.proc maybe_load_buttons
    dec button_data_timer+1
    beq +
    rts
  + dec button_data_timer+0
    beq +
    lda button_data_speed
    sta button_data_timer+1
    rts
  + dec progress_countdown
    bne +
    inc progress_level
    lda stat_changed
    ora #4
    sta stat_changed
    lda button_data_chunk_length
    sta progress_countdown
  + jmp process_button_data
.endp

.proc check_pause
    lda joypad0_posedge
    and #JOYPAD_BUTTON_START
    bne @@pause
    rts
    @@pause:
    lda #0
    ldy #27
    jsr set_fade_range
    jsr fade_out_step

    jsr pause_music
    jsr mixer_get_muted_channels
    sta tmp
    lda #$1F
    jsr mixer_set_muted_channels

    lda #2
    ldx #0
    jsr start_sfx

    lda #0
    sta selected_menu_item

    inc main_cycle ; game_paused_main
    rts
.endp

.proc game_paused_main
    jsr reset_sprites
    jsr draw_vu_pin
    jsr draw_points_level_indicator
    jsr draw_pause_menu
    jsr check_pause_input
    rts
.endp

.proc check_pause_input
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
    ldx #0
    jsr start_sfx
  + rts
    @@prev_item:
    lda selected_menu_item
    beq +
    dec selected_menu_item
    lda #1
    ldx #0
    jsr start_sfx
  + rts

    @@select_menu_item:
    ldy selected_menu_item
    beq @@unpause
    dey
    beq @@restart
    jmp @@quit
    
    @@unpause:
    jsr fade_in_step
    jsr unpause_music
    lda tmp
    jsr mixer_set_muted_channels
    dec main_cycle ; game main
    rts

    @@restart:
    lda #0
    jsr mixer_set_muted_channels
    lda #0 ; no song
    jsr start_song
    jsr unpause_music

    lda #0
    sta main_cycle
    lda #7
    ldy #7
    jsr start_timer
    ldcay @@really_restart
    jsr set_timer_callback
    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jmp start_fade_to_black

    @@quit:
    lda #0
    jsr mixer_set_muted_channels
    lda #0 ; no song
    jsr start_song
    jsr unpause_music

    lda #0
    sta main_cycle
    lda #7
    ldy #7
    jsr start_timer
    ldcay @@really_quit
    jsr set_timer_callback
    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jmp start_fade_to_black

    @@really_restart:
    lda #5
    sta main_cycle
    rts

    @@really_quit:
    lda #0
    jsr swap_bank
    lda #3
    sta main_cycle
    rts
.endp

.proc draw_pause_menu
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
    adc #96
    sta sprites._y,x
    lda selected_menu_item
    cmp menu_row
    beq +
    lda #2
    jmp ++
  + lda #3
 ++ sta sprites.attr,x
    lda menu_col
    asl
    asl
    asl
    adc #96
    sta sprites._x,x
    inc menu_col
    jmp -
    @@text_data:
.charmap "data/pausemenu.tbl"
.char "RESUME" : .db 0
.char "RESTART" : .db 0
.char "QUIT" : .db 0
.db 0
    rts
.endp

.proc check_if_done
    lda active_buttons_head
    cmp #$FF
    beq +
    rts
  + lda hit_buttons_head
    cmp #$FF
    beq +
    rts
  + lda missed_buttons_head
    cmp #$FF
    beq +
    rts
  + lda button_data.lo
    ora button_data.hi
    beq +
    rts
    ; no more buttons
  + jsr mixer_get_muted_channels
    and #$FC
    jsr mixer_set_muted_channels
    ; delay a bit before the round is over
    lda #24 ; ### customize the delay?
    jsr set_button_data_timer
    lda #8 ; game_done_main
    sta main_cycle
    rts
.endp

.proc game_done_main
    jsr reset_sprites
    jsr update_text_scroller
    jsr draw_vu_pin
    jsr draw_points_level_indicator
    dec button_data_timer+1
    beq +
    rts
  + dec button_data_timer+0
    beq +
    lda button_data_speed
    sta button_data_timer+1
    rts
  + lda #0
    sta main_cycle
    lda #7
    ldy #7
    jsr start_timer
    lda game_mode
    beq +
    ldcay go_character_screen
    jmp ++
  + ldcay show_stats
 ++ jsr set_timer_callback
    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jmp start_fade_to_black
.endp

; ### move all the stats stuff to separate prg bank
.proc show_stats
    jsr screen_off
    jsr nmi_off
    jsr reset_timers
    lda #0
    jsr fill_all_nametables
    lda #0
    tay
    jsr set_scroll_xy
    jsr reset_sprites

    lda #0
    jsr swap_bank

    lda #30 ; the big cup
    sta chr_banks+0
    lda #MMC3_MIRROR_H
    sta MMC3_MIRROR_REG

    lda #0
    jsr start_song

    jsr calculate_medal_from_score
    cmp #0
    php
    beq @@no_medal

    ; set new medal if it's better than old
    sta tmp
    lda selected_character
    jsr get_medal
    cmp tmp
    bcs +
    lda tmp
    jsr set_medal
    ; write name of medal
  + lda tmp
    asl
    tay
    lda @@medal_data_table-2,y
    pha
    lda @@medal_data_table-1,y
    tay
    pla
    jsr write_ppu_data_at
    ldcay @@congratulations_data
    jsr write_ppu_data_at
    jmp +

    @@no_medal:
    ldcay @@you_suck_data
    jsr write_ppu_data_at

  + ldcay @@interface_data
    jsr write_ppu_data_at

    ldcay @@palette
    jsr load_palette

    ; print the stats
    lda score
    sta AC0
    lda score+1
    sta AC1
    lda score+2
    sta AC2
    ldx #6
    lda #$20
    ldy #$93
    jsr print_value

    lda hit_count+0
    sta AC0
    lda hit_count+1
    sta AC1
    lda #0
    sta AC2
    ldx #3
    lda #$20
    ldy #$D6
    jsr print_value

    lda missed_count+0
    sta AC0
    lda missed_count+1
    sta AC1
    lda #0
    sta AC2
    ldx #3
    lda #$21
    ldy #$16
    jsr print_value

    lda error_count+0
    sta AC0
    lda error_count+1
    sta AC1
    lda #0
    sta AC2
    ldx #4
    lda #$21
    ldy #$55
    jsr print_value

    ; completion %: (hit_count * 100) / (hit_count + missed_count)
    ; part 1: multiply
    lda hit_count+0
    sta MULR+0
    lda hit_count+1
    sta MULR+1
    lda #0
    sta MULR+2
    sta MULR+3
    lda #100
    sta MULND+0
    lda #0
    sta MULND+1
    sta MULND+2
    sta MULND+3
    jsr MULTIPLY
    ; part 2: divide
    lda PROD+0
    sta AC0
    lda PROD+1
    sta AC1
    lda PROD+2
    sta AC2
    lda hit_count+0
    clc
    adc missed_count+0
    sta AUX0
    lda hit_count+1
    adc missed_count+1
    sta AUX1
    lda #0
    sta AUX2
    jsr divide
    ; figure out number of digits
    ldx #1
    lda AC0
    cmp #10
    bcc +
    inx
  + cmp #100
    bcc +
    inx
  + txa
    sec
    sbc #3
    eor #$FF
    clc
    adc #$95+1   ; 3 - number of digits + $55
    tay
    lda #$21
    jsr print_value

    lda longest_streak+0
    sta AC0
    lda longest_streak+1
    sta AC1
    lda #0
    sta AC2
    ldx #3
    lda #$21
    ldy #$D6
    jsr print_value

    plp ; ZF=1 if no medal
    beq +
    ldcay @@wait_for_start
    jsr start_zerotimer_with_callback
    lda #0
    jmp ++
  + lda #9
 ++ sta main_cycle

    jsr screen_on
    jsr nmi_on
    jmp start_fade_from_black

    @@wait_for_start:
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START | JOYPAD_BUTTON_A)
    bne @@begin_scrolling_to_medal
    ldcay @@wait_for_start
    jmp start_zerotimer_with_callback

    @@begin_scrolling_to_medal:
    lda #7
    jsr start_song
    ldcay @@scroll_to_medal
    jmp start_zerotimer_with_callback

    @@scroll_to_medal:
    jsr get_scroll_xy
    iny
    jsr set_scroll_xy
    cpy #216
    beq @@done_scrolling
    ldcay @@scroll_to_medal
    jmp start_zerotimer_with_callback
    @@done_scrolling:
    lda #0
    jsr start_song ; mute
    lda #9
    sta main_cycle
    rts

@@palette:
.db $0f,$20,$00,$10 ; text
.db $0f,$06,$16,$37 ; bronze
.db $0f,$00,$10,$20 ; silver
.db $0f,$17,$27,$37 ; gold
.db $0f,$06,$10,$30
.db $0f,$2A,$2A,$2A
.db $0f,$20,$20,$20
.db $0f,$20,$20,$20

@@interface_data:
.charmap "data/title.tbl"
.db $20,$87,$05
.char "SCORE"
.db $20,$C7,$04
.char "HITS"
.db $21,$07,$06
.char "MISSES"
.db $21,$47,$06
.char "ERRORS"
.db $21,$87,$0A
.char "COMPLETION"
.db $21,$98,$01
.char "%"
.db $21,$C7,$0A
.char "TOP STREAK"
.db 0

@@you_suck_data:
.db $22,$4A,11
.char "BETTER LUCK"
.db $22,$8B,9
.char "NEXT LIFE"
.db 0

@@congratulations_data:
.db $22,$8B,10
.char "PUSH START"
.db $22,$CD,6
.char "BUTTON"
.db $28,$08,16
.char "CONGRATULATIONS,"
.db $28,$49,14
.char "YOU EARNED THE"
.db $28,$CD,6
.char "MEDAL!"
.db 0

@@bronze_data:
.db $28,$8D,6
.char "BRONZE"
.incbin "data/pokal.dat"
.db $2B,$D0,$60,$55
.db 0
@@silver_data:
.db $28,$8D,6
.char "SILVER"
.incbin "data/pokal.dat"
.db $2B,$D0,$60,$AA
.db 0
@@gold_data:
.db $28,$8E,4
.char "GOLD"
.incbin "data/pokal.dat"
.db $2B,$D0,$60,$FF
.db 0

@@medal_data_table:
.dw @@bronze_data
.dw @@silver_data
.dw @@gold_data

.endp

.proc game_stats_main
    jsr reset_sprites
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START | JOYPAD_BUTTON_A)
    bne @@exit
    rts
    @@exit:
    lda #0
    ldx #4
    jsr start_sfx
    lda #0
    sta main_cycle
    lda #8
    ldy #8
    jsr start_timer
    jsr has_all_medals
    bne +
    ldcay go_character_screen
    jmp ++
  + ldcay @@go_theend
 ++ jsr set_timer_callback
    jsr start_fade_to_black
    rts

    @@go_theend:
    lda #0
    jsr swap_bank
    lda #13
    sta main_cycle
    rts
.endp

.proc has_all_medals
    lda medal_status
    and #%11000000
    beq +
    lda medal_status
    and #%00110000
    beq +
    lda medal_status
    and #%00001100
    beq +
    lda medal_status
    and #%00000011
  + rts
.endp

.proc go_character_screen
    lda #0
    jsr swap_bank
    lda #3
    sta main_cycle
    rts
.endp

.proc process_active_buttons
    lda #0
    sta tmp
    sta joybits
    lda #$FF
    sta prev
    ldy active_buttons_head
    @@loop:
    cpy #$FF ; end of list?
    bne @@do_button
    lda game_mode
    beq + ; only care about presses if we're in play mode
    rts
    ; any buttons that shouldn't have been pressed?
  + lda joybits
    eor joypad0
    and joypad0_posedge
    bne @@error
    rts
    @@error:
    jsr inc_error_count
.if 0 ; disabled for now
    lda #50
    jsr sub_score
    lda #3
    ldx #0
    jsr start_sfx
.endif
    rts
    @@do_button:
    jsr draw_button
    jsr move_button

    lda game_mode
    beq + ; check joypad if we're in play mode
    jmp @@buttons_matched ; the computer always wins
  + lda joypad0
    bne +
    jmp @@skip
    ; check if the correct joypad buttons are pressed
  + lda buttons.state,y
    lsr
    lsr
    lsr ; bit 0 = button
    tax
    lda bitmasktable,x
    and tmp
    beq +
    jmp @@skip ; we already checked buttons for this column
  + lda tmp
    ora bitmasktable,x
    sta tmp
    lda buttons.state,y
    and #$0F  ; button + modifiers
    tax
    lda @@joypad_bits,x
    and joypad0
    pha
    ora joybits
    sta joybits
    pla
    eor @@joypad_bits,x
    beq +
    jmp @@skip
  + lda @@joypad_bits,x
    and joypad0_posedge
    beq @@cheat_detected ; at least one button has to be pressed at this instant
    lda buttons.state,y
    and #7
    bne @@buttons_matched
    lda joypad0
    and #$0F             ; no directional button should be pressed
    beq @@buttons_matched
    @@cheat_detected:
    lda @@joypad_bits,x
    eor #$FF
    and joybits
    sta joybits
    jmp @@skip
    @@buttons_matched:
    lda buttons.pos.int,y
    cmp #174
    bcs @@button_hit
    ; all the buttons were pressed, but too soon -- error
    lda #$00
    sta joybits
    jmp @@skip
    @@button_hit:
    ; turn on the sound channel
    jsr mixer_get_muted_channels
    and #$FC
    jsr mixer_set_muted_channels
    ; increase stats
    jsr inc_hit_count
    jsr inc_streak
    lda current_streak+0
    and #3
    bne +
    jsr inc_vu_level
  + tya
    pha
    lda points_level
    asl
    tax
    lda @@scores+1,x
    tay
    lda @@scores+0,x
    jsr add_score
    pla
    tay

    lda buttons.state,y
    and #$F8 ; lower 3 bits will now be used for explosion frame index
    ora #$10 ; bit 4 indicates that the button is exploded (used by draw routine)
    sta buttons.state,y
    ; move to hit list
    lda buttons.next,y
    pha
    lda #$FF
    sta buttons.next,y
    ldx hit_buttons_tail
    sty hit_buttons_tail
    cpx #$FF
    bne +
    sty hit_buttons_head
    jmp ++
  + tya
    sta buttons.next,x
 ++ pla
    cpy active_buttons_tail
    bne +
    sta active_buttons_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty active_buttons_head
    jmp @@loop
  + sta buttons.next,x
    jmp @@loop

    @@skip:
    lda buttons.pos.int,y
    cmp #174+14
    bcs @@missed
    lda buttons.next,y
    sty prev
    tay
    jmp @@loop

    @@missed:
    lda #0
    sta points_level
    jsr dec_vu_level
    jsr inc_missed_count
    jsr reset_streak
    ; turn off the sound channel
    jsr mixer_get_muted_channels
    ora #3
    jsr mixer_set_muted_channels
    ; move to missed list
    lda buttons.next,y
    pha
    lda #$FF
    sta buttons.next,y
    ldx missed_buttons_tail
    sty missed_buttons_tail
    cpx #$FF
    bne +
    sty missed_buttons_head
    jmp ++
  + tya
    sta buttons.next,x
 ++ pla
    cpy active_buttons_tail
    bne +
    sta active_buttons_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty active_buttons_head
    jmp @@loop
  + sta buttons.next,x
    jmp @@loop

    @@joypad_bits:
    .db JOYPAD_BUTTON_B
    .db JOYPAD_BUTTON_B | JOYPAD_BUTTON_RIGHT
    .db JOYPAD_BUTTON_B | JOYPAD_BUTTON_LEFT
    .db JOYPAD_BUTTON_B | JOYPAD_BUTTON_DOWN
    .db JOYPAD_BUTTON_B | JOYPAD_BUTTON_UP
    .db 0,0,0 ; pad
    .db JOYPAD_BUTTON_A
    .db JOYPAD_BUTTON_A | JOYPAD_BUTTON_RIGHT
    .db JOYPAD_BUTTON_A | JOYPAD_BUTTON_LEFT
    .db JOYPAD_BUTTON_A | JOYPAD_BUTTON_DOWN
    .db JOYPAD_BUTTON_A | JOYPAD_BUTTON_UP
    .db 0,0,0 ; pad

    @@scores:
    .dw 25, 50, 75, 100
.endp

; Draws a button.
; Y = offset of button to draw
.proc draw_button
    jsr next_sprite_index
    tax
    lda buttons.state,y
    lsr
    lsr
    lsr
    lsr ; CF=button (0=B, 1=A)
    lda #113
    bcc +
    adc #19
  + pha
    sta sprites._x,x
    lda buttons.pos.int,y
    sta sprites._y,x
    lda buttons.state,y
    and #$17
    asl
    asl
    ora #$1
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    jsr next_sprite_index
    tax
    pla
    clc
    adc #8
    sta sprites._x,x
    lda buttons.pos.int,y
    sta sprites._y,x
    lda buttons.state,y
    and #$17
    asl
    asl
    ora #$3
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    rts
.endp

; Moves a button.
; Y = offset of button to move
.proc move_button
    lda buttons.pos.frac,y
    clc
    adc button_speed.frac
    sta buttons.pos.frac,y
    lda buttons.pos.int,y
    adc button_speed.int
    sta buttons.pos.int,y
    rts
.endp

.proc process_hit_buttons
    lda #$FF
    sta prev
    ldy hit_buttons_head
    @@loop:
    cpy #$FF
    bne +
    rts
  + jsr draw_button
    lda frame_count
    lsr
    bcc +
    lda buttons.state,y
    and #7
    cmp #7
    beq @@evaporated
    lda buttons.state,y
    clc
    adc #1
    sta buttons.state,y
  + lda buttons.next,y
    tay
    jmp @@loop

    @@evaporated:
    lda buttons.next,y
    pha
    ; put on free list
    lda free_buttons_list
    sta buttons.next,y
    sty free_buttons_list
    pla
    ; remove from hit buttons list
    cpy hit_buttons_tail
    bne +
    sta hit_buttons_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty hit_buttons_head
    jmp @@loop
  + sta buttons.next,x
    jmp @@loop
.endp

.proc process_missed_buttons
    lda #$FF
    sta prev
    ldy missed_buttons_head
    @@loop:
    cpy #$FF
    bne +
    rts
  + jsr draw_button
    jsr move_button

    lda buttons.pos.int,y
    cmp #240
    bcs @@fell_off
    lda buttons.next,y
    sty prev
    tay
    jmp @@loop

    @@fell_off:
    lda buttons.next,y
    pha
    ; put on free list
    lda free_buttons_list
    sta buttons.next,y
    sty free_buttons_list
    pla
    ; remove from missed buttons list
    cpy missed_buttons_tail
    bne +
    sta missed_buttons_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty missed_buttons_head
    jmp @@loop
  + sta buttons.next,x
    jmp @@loop
.endp

; Fetches the next byte of button data.
.proc fetch_button_data_byte
    ldy #0
    lda [button_data],y
    inc button_data.lo
    bne +
    inc button_data.hi
  + rts
.endp

; Adds a button.
; A = button (bit 3) and modifiers (bits 2..0)
; Y = duration
.proc add_button
; grab button from free list
    pha
    ldx free_buttons_list
    cpx #$FF
    bne +
    ; fatal, no more free buttons
    jmp reset
  + lda buttons.next,x
    sta free_buttons_list
    pla
; initialize the button
    sta buttons.state,x
    tya
    sta buttons.duration,x
    lda #16    ; initial Y position
    sta buttons.pos.int,x
    lda #0
    sta buttons.pos.frac,x
; add to end of active list
    lda #$FF
    sta buttons.next,x
    ldy active_buttons_tail
    stx active_buttons_tail
    cpy #$FF
    bne +
    stx active_buttons_head
    rts
  + txa
    sta buttons.next,y
    rts
.endp

.proc process_button_data
    jsr fetch_button_data_byte
    tay
    and #$F0
    beq @@set_next_delay ; if no buttons, skip
    bpl @@check_a
; B button on
    tya
    pha
    ldy #1
    and #$40 ; extended duration?
    beq +
    jsr fetch_button_data_byte
    tay
  + pla
    pha
    and #7 ; modifiers
    jsr add_button
    pla

    @@check_a:
    and #$20
    beq @@set_next_delay
; A button on
    tya
    pha
    ldy #1
    and #$10 ; extended duration?
    beq +
    jsr fetch_button_data_byte
    tay
  + pla
    and #7 ; modifiers
    ora #8 ; button = A
    jsr add_button

    @@set_next_delay:
    jsr fetch_button_data_byte
    ora #0
    beq @@at_end
; setup the next callback
    jsr set_button_data_timer
    rts

    @@at_end:
    lda #0
    sta button_data.lo
    sta button_data.hi
    rts
.endp

.proc inc_hit_count
    inc hit_count+0
    bne +
    inc hit_count+1
  + rts
.endp

.proc inc_missed_count
    inc missed_count+0
    bne +
    inc missed_count+1
  + rts
.endp

.proc inc_error_count
    inc error_count+0
    bne +
    inc error_count+1
  + rts
.endp

.proc inc_streak
    inc current_streak+0
    bne +
    inc current_streak+1
  + lda current_streak+1
    bne +
    lda current_streak+0
    cmp #8
    beq @@inc_points_level
    cmp #16
    beq @@inc_points_level
    cmp #24
    bne +
    @@inc_points_level:
    inc points_level
  + jmp sync_longest_streak
.endp

.proc sync_longest_streak
    lda longest_streak+0
    sec
    sbc current_streak+0
    lda longest_streak+1
    sbc current_streak+1
    bcs +
; new longest streak
    lda current_streak+0
    sta longest_streak+0
    lda current_streak+1
    sta longest_streak+1
  + rts
.endp

.proc reset_streak
    lda #0
    sta current_streak+0
    sta current_streak+1
    rts
.endp

.proc inc_vu_level
    lda vu_level
    cmp #12
    bcs +
    inc vu_level
  + rts
.endp

.proc dec_vu_level
    lda vu_level
    beq +
    dec vu_level
  + rts
.endp

; A = character (0..3)
.proc get_medal
    tay
    lda medal_status
  - dey
    bmi +
    lsr
    lsr
    jmp -
  + and #3
    rts
.endp

; Sets medal for current character.
; A = medal (0=none, 1=bronze, 2=silver, 3=gold)
.proc set_medal
    pha
    ldy selected_character
    lda @@medal_not_mask_table,y
    and medal_status ; clear the relevant bits
    sta medal_status
    pla
    and #3
  - dey
    bmi +
    asl
    asl
    jmp -
  + ora medal_status
    sta medal_status
    rts
@@medal_not_mask_table:
.db %11111100,%11110011,%11001111,%00111111
.endp

; Returns 0=none, 1=bronze, 2=silver, 3=gold
.proc calculate_medal_from_score
    lda selected_character
    asl
    asl
    asl
    asl
    ora #8
    tay
  - lda medal_score_table+0,y
    sec
    sbc score+0
    lda medal_score_table+1,y
    sbc score+1
    lda medal_score_table+2,y
    sbc score+2
    bcs +
    tya
    lsr
    lsr
    and #3
    clc
    adc #1
    rts
  + dey
    dey
    dey
    dey
    tya
    and #$0F
    cmp #$0C
    bne -
    lda #0 ; no medal
    rts
.endp

.proc sub_score
    eor #$FF
    clc
    adc #1
    adc score+0
    sta score+0
    lda score+1
    adc #$FF
    sta score+1
    lda score+2
    adc #$FF
    sta score+2
    bcs +
    lda #0
    sta score+0
    sta score+1
    sta score+2
  + lda stat_changed
    ora #1
    sta stat_changed
    rts
.endp

.proc add_score
    clc
    adc score+0
    sta score+0
    tya
    adc score+1
    sta score+1
    lda #0
    adc score+2
    sta score+2
    lda stat_changed
    ora #1
    sta stat_changed
    lda game_mode
    beq + ; only sync the top score if we're in play mode
    rts
  + jmp sync_top_score
.endp

.proc sync_top_score
    lda selected_character
    asl
    asl
    tay
    lda top_scores,y
    sec
    sbc score
    lda top_scores+1,y
    sbc score+1
    lda top_scores+2,y
    sbc score+2
    bcs +
; new top score
    lda score
    sta top_scores,y
    lda score+1
    sta top_scores+1,y
    lda score+2
    sta top_scores+2,y
    lda stat_changed
    ora #2
    sta stat_changed
  + rts
.endp

.proc draw_vu_pin
    ldy vu_level
    lda @@sprite_data_offsets,y
    tay
  - lda @@sprite_data+0,y
    bne +
    rts
  + jsr next_sprite_index
    tax
    lda @@sprite_data+0,y
    sta sprites._y,x
    lda @@sprite_data+1,y
    sta sprites.tile,x
    lda @@sprite_data+2,y
    sta sprites.attr,x
    lda @@sprite_data+3,y
    sta sprites._x,x
    iny
    iny
    iny
    iny
    jmp -
    @@sprite_data_offsets:
    .db @@l0-@@sprite_data
    .db @@l1-@@sprite_data
    .db @@l2-@@sprite_data
    .db @@l3-@@sprite_data
    .db @@l4-@@sprite_data
    .db @@l5-@@sprite_data
    .db @@l6-@@sprite_data
    .db @@l7-@@sprite_data
    .db @@l8-@@sprite_data
    .db @@l9-@@sprite_data
    .db @@l10-@@sprite_data
    .db @@l11-@@sprite_data
    .db @@l12-@@sprite_data
    @@sprite_data:
    @@l0:
    .db 170,$67,0,194
    .db 170,$69,0,194+8
    .db 170,$6B,0,194+16
    .db 0
    @@l1:
    .db 167,$6D,0,195
    .db 167,$6F,0,195+8
    .db 167,$71,0,195+16
    .db 0
    @@l2:
    .db 163,$61,0,198
    .db 163,$63,0,198+8
    .db 163+8,$65,0,198+16
    .db 0
    @@l3:
    .db 161,$73,0,202
    .db 161+8,$75,0,202+8
    .db 0
    @@l4:
    .db 160,$77,0,205
    .db 160+16,$79,0,205+8
    .db 0
    @@l5:
    .db 160,$7B,0,210
    .db 160+16,$7D,0,210
    .db 0
    @@l6:
    .db 159,$7F,0,215
    .db 159+16,$81,0,215
    .db 0
    @@l7:
    .db 160,$7B,$40+0,210+3
    .db 160+16,$7D,$40+0,210+3
    .db 0
    @@l8:
    .db 160,$77,$40+0,205+13
    .db 160+16,$79,$40+0,205+13-8
    .db 0
    @@l9:
    .db 161,$73,$40+0,202+19
    .db 161+8,$75,$40+0,202+19-8
    .db 0
    @@l10:
    .db 163,$61,$40+0,198+27
    .db 163,$63,$40+0,198+27-8
    .db 163+8,$65,$40+0,198+27-16
    .db 0
    @@l11:
    .db 167,$6D,$40+0,195+33
    .db 167,$6F,$40+0,195+33-8
    .db 167,$71,$40+0,195+33-16
    .db 0
    @@l12:
    .db 170,$67,$40+0,196+33
    .db 170,$69,$40+0,196+33-8
    .db 170,$6B,$40+0,196+33-16
    .db 0
.endp

.proc draw_points_level_indicator
    lda points_level
    bne +
    rts
  + jsr next_sprite_index
    tay
    lda #$31
    sta sprites.tile,y
    lda #185
    pha
    sta sprites._y,y
    lda #208
    sta sprites._x,y
    lda #1
    sta sprites.attr,y
    jsr next_sprite_index
    tay
    lda points_level
    asl
    adc #$31
    sta sprites.tile,y
    pla
    sta sprites._y,y
    lda #208+8
    sta sprites._x,y
    lda #1
    sta sprites.attr,y
    rts
.endp

.proc update_score_displays
    lda stat_changed
    lsr
    bcs @@update_score
    lsr
    bcs @@update_top_score
    rts
    @@update_score:
    asl
    sta stat_changed
    jmp print_score

    @@update_top_score:
    lda stat_changed
    and #~2
    sta stat_changed
    jmp print_top_score
.endp

.proc print_score
    lda score
    sta AC0
    lda score+1
    sta AC1
    lda score+2
    sta AC2
    ldx #6
    lda #$20
    ldy #$4D
    jmp print_value
.endp

.proc print_top_score
    lda selected_character
    asl
    asl
    tay
    lda top_scores,y
    sta AC0
    lda top_scores+1,y
    sta AC1
    lda top_scores+2,y
    sta AC2
    ldx #6
    lda #$20
    ldy #$59
    jmp print_value
.endp

; AC0, AC1, AC2 = value to print
; X = # of digits to output
; A = PPU high address
; Y = PPU low address
.proc print_value
    stx     Count
    ldx     ppu_buffer_offset
    sta     ppu_buffer,x
    inx
    tya
    sta     ppu_buffer,x
    inx
    lda     Count
    sta     ppu_buffer,x
    inx
    lda     #10
    sta     AUX0
    lda     #0
    sta     AUX1
    sta     AUX2
    ldy     Count
    cpy     #0
    bne     +
    ; figure out how many digits to print
  - iny
    cpy     #7
    beq     +
    lda     AC0
    sec
    sbc     @@DecPos0-1,y
    lda     AC1
    sbc     @@DecPos1-1,y
    lda     AC2
    sbc     @@DecPos2-1,y
    bcs     -
  + sty     Count
  - jsr     divide
    lda     XTND0
    pha
    dey
    bne     -
  - pla
    ora     #$D0
    sta     ppu_buffer,x
    inx
    iny
    cpy     Count
    bne     -
    jmp     end_ppu_string
@@DecPos0:
.db $0A,$64,$E8,$10,$A0,$40
@@DecPos1:
.db $00,$00,$03,$27,$86,$42
@@DecPos2:
.db $00,$00,$00,$00,$01,$0F
.endp

.proc divide
    txa
    pha
    tya
    pha
    ldy #24      ; bitwidth
    lda #0
    sta XTND0
    sta XTND1
    sta XTND2
  - asl AC0      ;DIVIDEND/2, CLEAR QUOTIENT BIT
    rol AC1
    rol AC2
    rol XTND0
    rol XTND1
    rol XTND2
    lda XTND0    ;TRY SUBTRACTING DIVISOR
    sec
    sbc AUX0
    sta TMP0
    lda XTND1
    sbc AUX1
    tax
    lda XTND2
    sbc AUX2
    bcc +    ;TOO SMALL, QBIT=0
    stx XTND1    ;OKAY, STORE REMAINDER
    sta XTND2
    lda TMP0
    sta XTND0
    inc AC0      ;SET QUOTIENT BIT = 1
  + dey          ;NEXT STEP
    bne -
    pla
    tay
    pla
    tax
    rts
.endp

.proc update_progress_display
    lda stat_changed
    and #4
    bne +
    rts
  + lda stat_changed
    and #~4
    sta stat_changed
    lda progress_level
    cmp #39
    bcc +
    rts
  + sec
    sbc #1
    lsr
    clc
    adc #$8C
    ldy #$20
    ldx #$82 ; 2 tiles vertically
    jsr begin_ppu_string
    lda progress_level
    and #1 ; odd or even
    asl
    adc #$0A
    pha
    jsr put_ppu_string_byte
    pla
    clc
    adc #1
    jsr put_ppu_string_byte
    jmp end_ppu_string
.endp

.proc update_audience
    lda audience_status
    and #$7F
    beq +
    ldy audience_status
    dey
    sty audience_status
    rts
  + lda audience_status
    and #$80 ; clear timer bits
    lda #48
    sec
    sbc vu_level
    sbc vu_level
    sbc vu_level
    ora audience_status
    eor #$80 ; flip frame
    sta audience_status
    rol ; carry = audience frame
    lda vu_level
    rol
    tay
    lda @@audience_data_offsets,y
    tay
    ldx ppu_buffer_offset
  - lda @@audience_data,y
    beq +
    sta ppu_buffer,x
    inx
    iny
    jmp -
  + sta ppu_buffer,x ; 0
    stx ppu_buffer_offset
    rts
    @@audience_data_offsets:
    ; level 0 (nothing)
    .db @@f0-@@audience_data
    .db @@f0-@@audience_data
    ; level 1 (nothing)
    .db @@f0-@@audience_data
    .db @@f0-@@audience_data
    ; level 2
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 3
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 4
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 5
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 6
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 7
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 8
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 9
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 10
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 11
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    ; level 12
    .db @@f1-@@audience_data
    .db @@f2-@@audience_data
    @@audience_data:
    @@f0:
    .db 0
    @@f1:
    .db $21,$3C,$02,$A7,$A8
    .db $21,$5C,$02,$B7,$B8
    .db 0
    @@f2:
    .db $21,$3C,$02,$8C,$8D
    .db $21,$5C,$02,$8E,$8F
    .db 0
.endp

.proc update_text_scroller
    dec text_scroller_timer
    beq +
    rts
  + ldy #$23
    lda #$61
    ldx #30
    jsr begin_ppu_string
    ldy text_scroller_offset
    inc text_scroller_offset
    lda #30
    @@loop:
    pha
    lda [text_scroller_data],y
    cmp #$FF   ; EOD?
    bne @@skip
    ldy #0
    sty text_scroller_offset
    lda [text_scroller_data],y
    @@skip:
    jsr put_ppu_string_byte
    iny
    pla
    sec
    sbc #1
    bne @@loop
    jsr end_ppu_string

    lda #3*4
    sta text_scroller_timer
    rts
.endp

text_scroller_data_table:
.dw sweet_scroller_text
.dw harder_scroller_text
.dw feel_scroller_text
.dw swing_scroller_text

.charmap "data/title.tbl"
sweet_scroller_text:
.char "                             NOW PLAYING `SWEET`        ORIGINAL `SWEET CHILD OF MINE` BY GUNS N' ROSES 1987                             ",$FF
harder_scroller_text:
.char "                             NOW PLAYING `HARDER`       ORIGINAL `HARDER, BETTER, FASTER, STRONGER` BY DAFT PUNK 2001                             ",$FF
feel_scroller_text:
.char "                             NOW PLAYING `FEEL`         ORIGINAL `THE WAY YOU MAKE ME FEEL` BY MICHAEL JACKSON 1987                             ",$FF
swing_scroller_text:
.char "                             NOW PLAYING `SWING`        ORIGINAL `THE SWING OF THINGS` BY A-HA 1986                             ",$FF

medal_score_table:
; bronze, silver, gold
; sweet
.dd 30000,40000,50000,0
; harder
.dd 30000,40000,50000,0
; feel
.dd 30000,40000,50000,0
; swing
.dd 35000,45000,50000,0

; bit 7: B
; bit 6: B extended duration?
; bit 5: A
; bit 4: A extended duration?
; bit 3: unused
; bits 2..0: modifiers (0=none, 1=right, 2=left, 3=down, 4=up, 5=unused, 6=unused, 7=unused)

; ### move button data to separate file

button_data_table:
; faster speed:
; .db 6, 2, 1, 128, 16, 0 : .dw sweet_button_data
; .db 5, 1, 1, 128, 2, 0 : .dw harder_button_data
.db 6, 2, 1, 0, 24, 0 : .dw sweet_button_data
.db 5, 1, 1, 0, 1, 0 : .dw harder_button_data
.db 4, 3, 1, 64, 27, 0 : .dw feel_button_data
.db 3, 4, 1, 64, 23, 0 : .dw swing_button_data

.end
