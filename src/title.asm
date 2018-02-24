.include "common/ppu.h"
.include "common/joypad.h"
.include "common/sprite.h"
.include "common/ldc.h"
.include "mmc/mmc3.h"

.dataseg

.codeseg

.extrn ppu:ppu_state
.extrn sprites:sprite_state
.extrn sprite_index:byte

.extrn nmi_off:proc
.extrn nmi_on:proc
.extrn reset_timers:proc
.extrn screen_off:proc
.extrn screen_on:proc
.extrn set_black_palette:proc
.extrn load_palette:proc
.extrn set_fade_range:proc
.extrn set_fade_delay:proc
.extrn start_fade_from_black:proc
.extrn start_fade_to_black:proc
.extrn start_timer:proc
.extrn set_timer_callback:proc
.extrn fill_all_nametables:proc
.extrn write_ppu_data_at:proc
.extrn set_scroll_xy:proc
.extrn reset_sprites:proc
.extrn swap_bank:proc
.extrn start_song:proc
.extrn start_square_sfx:proc
.extrn main_cycle:byte
.extrn joypad0_posedge:byte

.ifdef MMC
.if MMC == 3
.extrn chr_banks:byte
.endif
.endif

.public title_init
.public title_main

.proc title_init
    jsr nmi_off
    jsr screen_off
    jsr reset_timers
    lda #0
    jsr fill_all_nametables
    lda #0
    tay
    jsr set_scroll_xy

    jsr reset_sprites
    lda ppu.ctrl0
    ora #PPU_CTRL0_SPRITE_SIZE_8x16
    ora #1 ; initially display the 2nd nametable
    sta ppu.ctrl0

.ifdef MMC
.if MMC == 3
    lda #0
    sta chr_banks[0]
    lda #16 ; needed for font
    sta chr_banks[1]
    lda #4
    sta chr_banks[2]
    lda #5
    sta chr_banks[3]
    lda #6
    sta chr_banks[4]
    lda #7
    sta chr_banks[5]
    lda #0
    jsr swap_bank
    lda #MMC3_MIRROR_V
    sta MMC3_MIRROR_REG
.endif
.endif

    ldcay @@title_data
    jsr write_ppu_data_at

    jsr set_black_palette
    ldcay @@palette
    jsr load_palette

    lda #5
    ldy #5
    jsr start_timer
    ldcay @@fade_in_logo
    jsr set_timer_callback

    lda #0
    sta main_cycle

    jsr screen_on
    jsr nmi_on
    rts

    @@fade_in_logo:
    lda #6
    jsr start_song
    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jsr start_fade_from_black

    lda #16
    ldy #7
    jsr start_timer
    ldcay @@logo_done
    jsr set_timer_callback
    rts

    @@logo_done:
    jsr start_fade_to_black
    lda #8
    ldy #7
    jsr start_timer
    ldcay @@logo_faded_out
    jsr set_timer_callback
    rts

    @@logo_faded_out:
    jsr screen_off
    ldcay @@second_title_data
    jsr write_ppu_data_at
    jsr start_fade_from_black
    lda #16
    ldy #7
    jsr start_timer
    ldcay @@second_logo_done
    jsr set_timer_callback
    jsr screen_on
    rts

    @@second_logo_done:
    jsr start_fade_to_black
    lda #8
    ldy #7
    jsr start_timer
    ldcay @@second_logo_faded_out
    jsr set_timer_callback
    rts

    @@second_logo_faded_out:
    lda ppu.ctrl0
    and #~1 ; switch to the title screen nametable
    sta ppu.ctrl0
    lda #2 ; 2nd half of title screen
    sta chr_banks[1]

    jsr start_fade_from_black

    lda #7
    ldy #5
    jsr start_timer
    ldcay @@title_faded_in
    jsr set_timer_callback

    jsr reset_sprites
    jsr draw_bg_sprites
    rts

    @@title_faded_in:
    lda #2 ; title_main
    sta main_cycle
    rts

@@palette:
.db $0f,$0C,$00,$20,$0f,$20,$20,$20,$0f,$06,$00,$10,$0f,$06,$00,$10
.db $0f,$0C,$00,$20,$0f,$20,$20,$20,$0f,$20,$20,$20,$0f,$20,$20,$20

@@title_data:
.incbin "data/titlelogo.dat"
.charmap "data/title.tbl"
.db $2D,$CA,12
.char "DPADHERO.COM"
.db $2F,$D8,$48,$55
.db $2E,$0C,8
.char "PRESENTS"
.db $2F,$D8,$50,$55
.db 0
@@second_title_data:
.db $2D,$CA,12
.char " A SHOCKER  "
.db $2F,$D8,$48,$55
.db $2E,$09,14
.char "OF A ROCKER..."
.db $2F,$D8,$50,$55
.db 0
.endp

.proc title_main
    jsr reset_sprites
    jsr draw_bg_sprites

    lda joypad0_posedge
    and #JOYPAD_BUTTON_START
    bne @@start
    rts

    @@start:
    ldy #0
    jsr start_square_sfx

    lda #7
    ldy #10
    jsr start_timer
    lda #<@@really_start
    ldy #>@@really_start
    jsr set_timer_callback

    jsr start_fade_to_black

    lda #0
    sta main_cycle
    rts

    @@really_start:
    lda #3
    sta main_cycle
    rts
.endp

; the BG doesn't fit in 4K, so part of the "background" is composed of sprites
.proc draw_bg_sprites
    ldy #0
    ldx sprite_index
    @@loop:
    lda bg_sprites._y,y
    sta sprites._y,x
    lda bg_sprites.tile,y
    sta sprites.tile,x
    lda bg_sprites.attr,y
    sta sprites.attr,x
    lda bg_sprites._x,y
    sta sprites._x,x
    txa
    clc
    adc #SPRITE_INDEX_INCR
    tax
    iny
    iny
    iny
    iny
    cpy #44
    bne @@loop
    stx sprite_index
    rts
.endp

BASE_Y .equ 119
.label bg_sprites:sprite_state
.sprite_state { BASE_Y+11, 1, {0}, 88 }
.sprite_state { BASE_Y, 3, {0}, 88+8 }
.sprite_state { BASE_Y+16, 5, {0}, 88+8 }
.sprite_state { BASE_Y, 7, {0}, 88+16 }
.sprite_state { BASE_Y+24, 9, {0}, 88+16 }
.sprite_state { BASE_Y+24+6, 11, {0}, 88+24 }
.sprite_state { BASE_Y+24+6+16, 13, {0}, 88+24 }
.sprite_state { BASE_Y+32, 15, {0}, 88+32 }
.sprite_state { BASE_Y-8, 17, {0}, 88+64 }
.sprite_state { BASE_Y+8, 19, {0}, 88+64 }
.sprite_state { BASE_Y+24, 21, {0}, 88+64 }

.end
