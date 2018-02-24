ram{start=$000,end=$1C0}
ram{start=$200,end=$800}
output{file=dpadhero.nes}
copy{file=data/dpadhero.hdr}
# Bank 0
bank{size=$4000,origin=$8000}
link{file=title.o}
link{file=password.o}
link{file=characterselect.o}
link{file=theend.o}
link{file=data/select.o}
link{file=data/aero.o}
link{file=data/fanfare.o}
# Bank 1
bank{size=$4000,origin=$8000}
# Bank 2
bank{size=$4000,origin=$8000}
# Bank 3
bank{size=$4000,origin=$8000}
link{file=data/swing.o}
# Bank 4
bank{size=$4000,origin=$8000}
link{file=data/feel.o}
# Bank 5
bank{size=$4000,origin=$8000}
link{file=data/harder.o}
# Bank 6
bank{size=$4000,origin=$8000}
link{file=data/sweet.o}
# Bank 7
bank{size=$4000,origin=$C000}
link{file=bitmasktable.o}
link{file=periodtable.o}
link{file=volumetable.o}
link{file=envelope.o}
link{file=effect.o}
link{file=tonal.o}
link{file=dmc.o}
link{file=mixer.o}
link{file=sequencer.o}
link{file=sfx.o}
link{file=sound.o}
link{file=sprite.o}
link{file=tablecall.o}
link{file=ppu.o}
link{file=ppuwrite.o}
link{file=ppubuffer.o}
link{file=joypad.o}
link{file=timer.o}
link{file=palette.o}
link{file=fade.o}
link{file=irq.o}
link{file=nmi.o}
link{file=reset.o}
link{file=mmc3.o}
link{file=sfxdata.o}
link{file=mutesong.o}
link{file=songtable.o}
link{file=multiply.o}
link{file=main.o}
link{file=sweetbuttons.o}
link{file=harderbuttons.o}
link{file=feelbuttons.o}
link{file=swingbuttons.o}
pad{origin=$F980}
link{file=dmcdata.o}
pad{origin=$FFFA}
link{file=vectors.o}
# CHR banks
bank{size=$20000}
copy{file=chr/title-bg.chr}
copy{file=chr/title-sprites.chr}
copy{file=chr/title-sprites.chr}
copy{file=chr/title-sprites.chr}
copy{file=chr/title-sprites.chr}
copy{file=chr/characterselect.chr}
copy{file=chr/dpadhero.chr}
copy{file=chr/password.chr}
copy{file=chr/pokal-packed.chr}
copy{file=chr/nespaper-packed.chr}
pad{origin=$20000}
