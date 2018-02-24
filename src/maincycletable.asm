.extrn title_init:proc
.extrn title_main:proc
.extrn characterselect_init:proc
.extrn characterselect_main:proc
.extrn game_init:proc
.extrn game_main:proc
.extrn game_paused_main:proc
.extrn game_done_main:proc
.extrn game_stats_main:proc
.extrn enter_password_init:proc
.extrn enter_password_main:proc
.extrn song_selected_main:proc
.extrn theend_init:proc
.extrn theend_main:proc

TC_SLOT noop_cycle
TC_SLOT title_init
TC_SLOT title_main
TC_SLOT characterselect_init
TC_SLOT characterselect_main
TC_SLOT game_init
TC_SLOT game_main
TC_SLOT game_paused_main
TC_SLOT game_done_main
TC_SLOT game_stats_main
TC_SLOT enter_password_init
TC_SLOT enter_password_main
TC_SLOT song_selected_main
TC_SLOT theend_init
TC_SLOT theend_main

noop_cycle:
rts
