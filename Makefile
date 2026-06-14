CFLAGS = -std=gnu89 -w -O

CLEANFILES =				\
	lisp				\
	lisp.o				\
	bestline.o			\
	sectorlisp.o			\
	sectorlisp.bin			\
	sectorlisp.bin.dbg

.PHONY:	all
all:	lisp				\
	bin/sectorlisp.bin		\
	bin/sectorlisp.bin.dbg

.PHONY:	clean
clean:;	$(RM) lisp lisp.o bestline.o sectorlisp.o bin/sectorlisp.bin bin/sectorlisp.bin.dbg

lisp: lisp.o bestline.o
lisp.o: lisp.c bestline.h
bestline.o: bestline.c bestline.h

bin/sectorlisp.o: sectorlisp.S
	$(AS) -g -o $@ $<

bin/sectorlisp.bin.dbg: bin/sectorlisp.o sectorlisp.lds
	$(LD) -T sectorlisp.lds -o $@ $<

bin/sectorlisp.bin: bin/sectorlisp.bin.dbg
	objcopy -S -O binary $< $@
