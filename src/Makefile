BASESRCDIR = ../../../src

AFLAGS = --debug -DMMC=3 -I. -I$(BASESRCDIR)

LFLAGS = 

XASM = xasm $(AFLAGS)

XLNK = xlnk $(LFLAGS)

COMMON_OBJS = \
    bitmasktable.o \
    sprite.o \
    tablecall.o \
    joypad.o \
    ppu.o \
    ppuwrite.o \
    ppubuffer.o \
    timer.o \
    palette.o \
    fade.o \
    irq.o \
    nmi.o \
    reset.o \
    vectors.o

SOUND_OBJS = \
    periodtable.o \
    volumetable.o \
    envelope.o \
    effect.o \
    tonal.o \
    dmc.o \
    mixer.o \
    sequencer.o \
    sound.o \
    sfx.o

OBJS = $(COMMON_OBJS) $(SOUND_OBJS) \
    mmc3.o \
    main.o \
    sweetbuttons.o \
    harderbuttons.o \
    feelbuttons.o \
    swingbuttons.o \
    title.o \
    characterselect.o \
    theend.o \
    password.o \
    multiply.o \
    dmcdata.o \
    sfxdata.o \
    mutesong.o \
    songtable.o

PROGRAM = dpadhero

HEADERFILE = data/$(PROGRAM).hdr

SCRIPTFILE = $(PROGRAM).s

BINFILE = $(PROGRAM).nes

CHRS = chr/title-bg.chr \
    chr/title-sprites.chr \
    chr/characterselect.chr \
    chr/dpadhero.chr \
    chr/password.chr \
    chr/pokal-packed.chr \
    chr/nespaper-packed.chr

$(BINFILE): $(OBJS) $(HEADERFILE) $(SCRIPTFILE) $(CHRS)
	$(XLNK) $(SCRIPTFILE)

sfx.o: $(BASESRCDIR)/sound/sfx.asm
	$(XASM) $< -o $@

periodtable.o: $(BASESRCDIR)/sound/periodtable.asm
	$(XASM) $< -o $@

volumetable.o: $(BASESRCDIR)/sound/volumetable.asm
	$(XASM) $< -o $@

envelope.o: $(BASESRCDIR)/sound/envelope.asm
	$(XASM) $< -o $@

effect.o: $(BASESRCDIR)/sound/effect.asm
	$(XASM) $< -o $@

tonal.o: $(BASESRCDIR)/sound/tonal.asm
	$(XASM) $< -o $@

dmc.o: $(BASESRCDIR)/sound/dmc.asm
	$(XASM) $< -o $@

sequencer.o: $(BASESRCDIR)/sound/sequencer.asm
	$(XASM) $< -o $@

mixer.o: $(BASESRCDIR)/sound/mixer.asm
	$(XASM) $< -o $@

sound.o: $(BASESRCDIR)/sound/sound.asm
	$(XASM) $< -o $@

bitmasktable.o: $(BASESRCDIR)/common/bitmasktable.asm
	$(XASM) $< -o $@

timer.o: $(BASESRCDIR)/common/timer.asm
	$(XASM) $< -o $@

sprite.o: $(BASESRCDIR)/common/sprite.asm
	$(XASM) $< -o $@

tablecall.o: $(BASESRCDIR)/common/tablecall.asm
	$(XASM) $< -o $@

joypad.o: $(BASESRCDIR)/common/joypad.asm
	$(XASM) $< -o $@

ppu.o: $(BASESRCDIR)/common/ppu.asm
	$(XASM) $< -o $@

ppuwrite.o: $(BASESRCDIR)/common/ppuwrite.asm
	$(XASM) $< -o $@

ppubuffer.o: $(BASESRCDIR)/common/ppubuffer.asm
	$(XASM) $< -o $@

palette.o: $(BASESRCDIR)/common/palette.asm
	$(XASM) $< -o $@

fade.o: $(BASESRCDIR)/common/fade.asm
	$(XASM) $< -o $@

irq.o: $(BASESRCDIR)/common/irq.asm
	$(XASM) $< -o $@

nmi.o: $(BASESRCDIR)/common/nmi.asm maincycletable.asm
	$(XASM) $< -o $@

reset.o: $(BASESRCDIR)/common/reset.asm
	$(XASM) $< -o $@

vectors.o: $(BASESRCDIR)/common/vectors.asm
	$(XASM) $< -o $@

mmc3.o: $(BASESRCDIR)/mmc/mmc3.asm
	$(XASM) $< -o $@

main.o: main.asm data/dpad.dat data/vu.dat data/audience.dat data/pausemenu.tbl data/title.tbl
	$(XASM) $< -o $@

sweetbuttons.o: sweetbuttons.asm
	$(XASM) $< -o $@

harderbuttons.o: harderbuttons.asm
	$(XASM) $< -o $@

feelbuttons.o: feelbuttons.asm
	$(XASM) $< -o $@

swingbuttons.o: swingbuttons.asm
	$(XASM) $< -o $@

title.o: title.asm data/titlelogo.dat
	$(XASM) $< -o $@

characterselect.o: characterselect.asm data/characterselect.tbl data/sweet-select.dat data/harder-select.dat data/feel-select.dat data/swing-select.dat
	$(XASM) $< -o $@

theend.o: theend.asm data/nespaper.dat
	$(XASM) $< -o $@

multiply.o: multiply.asm
	$(XASM) $< -o $@

password.o: password.asm
	$(XASM) $< -o $@

dmcdata.o: dmcdata.asm
	$(XASM) $< -o $@

sfxdata.o: sfxdata.asm
	$(XASM) $< -o $@

mutesong.o: mutesong.asm
	$(XASM) $< -o $@

songtable.o: songtable.asm
	$(XASM) $< -o $@

.PHONY: clean

clean:
	-rm -f $(BINFILE) $(OBJS)
