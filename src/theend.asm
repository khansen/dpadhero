.include "common/ppu.h"
.include "common/joypad.h"
.include "common/sprite.h"
.include "common/ldc.h"
.include "mmc/mmc3.h"

.dataseg

.extrn chr_banks:byte

.codeseg

.public theend_init
.public theend_main

.extrn nmi_off:proc
.extrn nmi_on:proc
.extrn screen_off:proc
.extrn screen_on:proc
.extrn fill_all_nametables:proc
.extrn set_scroll_xy:proc
.extrn reset_sprites:proc
.extrn reset_timers:proc
.extrn write_ppu_data_at:proc
.extrn set_black_palette:proc
.extrn load_palette:proc
.extrn start_song:proc
.extrn set_fade_range:proc
.extrn set_fade_delay:proc
.extrn start_fade_from_black:proc
.extrn start_timer:proc
.extrn set_timer_callback:proc
.extrn start_fade_to_black:proc
.extrn main_cycle:byte
.extrn medal_status:byte
.extrn joypad0_posedge:byte

.proc theend_init
    jsr nmi_off
    jsr screen_off
    jsr reset_timers
    lda #0
    jsr fill_all_nametables
    lda #0
    tay
    jsr set_scroll_xy

    jsr reset_sprites

    jsr has_only_gold_medals
.ifdef MMC
.if MMC == 3
    php
    bne +
    ; paper
    lda #32
    sta chr_banks[0]
    lda #34
    sta chr_banks[1]
    jmp ++
  + lda #14
    sta chr_banks[0]
    lda #16
    sta chr_banks[1]
 ++ plp
.endif
.endif

    php
    bne +
    ldcay @@theend_data
    jmp ++
  + ldcay @@theend_sucky_data
 ++ jsr write_ppu_data_at
    plp

    jsr set_black_palette
    ldcay @@palette
    jsr load_palette

    lda #6
    jsr start_song
    lda #0
    ldy #31
    jsr set_fade_range
    lda #7
    jsr set_fade_delay
    jsr start_fade_from_black

    inc main_cycle

    jsr screen_on
    jsr nmi_on
    rts

@@palette:
.db $0f,$00,$10,$20,$0f,$20,$20,$20,$0f,$16,$00,$1C,$0f,$06,$00,$10
.db $0f,$0C,$00,$20,$0f,$20,$20,$20,$0f,$20,$20,$20,$0f,$20,$20,$20

@@theend_sucky_data:
.charmap "data/title.tbl"
.db $20,$C9,15
.char "YOU WON A MEDAL"
.db $21,$09,15
.char "IN EVERY EVENT."
.db $21,$8B,10
.char "NICE WORK!"
.db $22,$0B,10
.char "GO FOR ALL"
.db $22,$49,14
.char "4 GOLD MEDALS!"
; d-pad hero logo
.db $22,$CD,$06,$53,$54,$55,$56,$57,$58
.db $22,$ED,$06,$59,$5A,$5B,$5C,$5D,$5E
.db $23,$0D,$06,$81,$82,$83,$84,$85,$86
.db $23,$2E,$05,$87,$88,$89,$8A,$8B
; attrib table
.db $23,$C0,$60,$55
.db $23,$E0,$48,$55
.db $23,$E8,$50,$AA
.db 0

@@theend_data:
.incbin "data/nespaper.dat"
.db 0
.endp

; Returns ZF=1 if only gold medals, otherwise ZF=1
.proc has_only_gold_medals
    lda medal_status
    and #%11000000
    cmp #%11000000
    bne +
    lda medal_status
    and #%00110000
    cmp #%00110000
    bne +
    lda medal_status
    and #%00001100
    cmp #%00001100
    bne +
    lda medal_status
    and #%00000011
    cmp #%00000011
  + rts
.endp

.proc theend_main
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START | JOYPAD_BUTTON_A)
    bne @@check_exit
    rts
    @@check_exit:
    jsr has_only_gold_medals
    bne @@exit
    rts
    @@exit:
    lda #7
    ldy #10
    jsr start_timer
    lda #<@@really_exit
    ldy #>@@really_exit
    jsr set_timer_callback
    jsr start_fade_to_black
    lda #0
    sta main_cycle
    rts
    @@really_exit:
    lda #3
    sta main_cycle
    rts
.endp

.end
