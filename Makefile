CFLAGS = -w -g

CLEANFILES =				\
	lisp				\
	lisp.o				\
	bestline.o			\
	sectorlisp.o			\
	sectorlisp.bin			\
	sectorlisp.bin.dbg

.PHONY:	all
all:	lisp				\
	sectorlisp.bin			\
	sectorlisp.bin.dbg

.PHONY:	clean
clean:;	$(RM) lisp lisp.o bestline.o sectorlisp.o sectorlisp.bin sectorlisp.bin.dbg

lisp: lisp.o bestline.o
lisp.o: lisp.js bestline.h
bestline.o: bestline.c bestline.h

sectorlisp.o: sectorlisp.S
	$(AS) -g -o $@ $<

sectorlisp.bin.dbg: sectorlisp.o
	$(LD) -oformat:binary -Ttext=0x0000 -o $@ $<

sectorlisp.bin: sectorlisp.bin.dbg
	objcopy -S -O binary sectorlisp.bin.dbg sectorlisp.bin

%.o: %.js
	$(COMPILE.c) -xc $(OUTPUT_OPTION) $<
