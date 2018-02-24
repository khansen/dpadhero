.codeseg

.public MUTE_song

MUTE_chn0_ptn0:
.db $08,$01,$F2,$00,$F4
MUTE_chn1_ptn0:
.db $08,$01,$F2,$00,$F4
MUTE_chn2_ptn0:
.db $08,$01,$E0,$F1,$F4
MUTE_chn3_ptn0:
.db $08,$01,$F2,$00,$F4
MUTE_pattern_table:
.dw MUTE_chn0_ptn0
.dw MUTE_chn1_ptn0
.dw MUTE_chn2_ptn0
.dw MUTE_chn3_ptn0
MUTE_song:
.db 0,7
.db 3,7
.db 6,7
.db 9,7
.db $FF
.dw 0 ; MUTE_instrument_table
.dw MUTE_pattern_table
.db $00
.db $FE,0
.db $01
.db $FE,3
.db $02
.db $FE,6
.db $03
.db $FE,9

.end
