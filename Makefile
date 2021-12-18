CFLAGS = -w -g -O2

CLEANFILES =				\
	lisp				\
	lisp.o				\
	hash				\
	bestline.o			\
	sectorlisp.o			\
	sectorlisp.bin			\
	sectorlisp.bin.dbg		\
	brainfuck.o			\
	brainfuck.bin			\
	brainfuck.bin.dbg

.PHONY:	all
all:	lisp				\
	hash				\
	sectorlisp.bin			\
	sectorlisp.bin.dbg		\
	brainfuck.bin			\
	brainfuck.bin.dbg

.PHONY:	clean
clean:;	$(RM) $(CLEANFILES)

lisp: lisp.o bestline.o
lisp.o: lisp.js bestline.h
bestline.o: bestline.c bestline.h

sectorlisp.o: sectorlisp.S
	$(AS) -g -o $@ $<

sectorlisp.bin.dbg: sectorlisp.o
	$(LD) -oformat:binary -Ttext=0x0000 -o $@ $<

sectorlisp.bin: sectorlisp.bin.dbg
	objcopy -S -O binary sectorlisp.bin.dbg sectorlisp.bin

brainfuck.o: brainfuck.S
	$(AS) -g -o $@ $<

brainfuck.bin.dbg: brainfuck.o
	$(LD) -oformat:binary -Ttext=0x7c00 -o $@ $<

brainfuck.bin: brainfuck.bin.dbg
	objcopy -S -O binary brainfuck.bin.dbg brainfuck.bin

.PHONY:	check
check:
	./checkjumps.sh
	gcc -w -c -o /dev/null -xc lisp.js
	clang -w -c -o /dev/null -xc lisp.js
	gcc -Wall -Werror -c -o /dev/null hash.c
	clang -Wall -Werror -c -o /dev/null hash.c

%.o: %.js
	$(COMPILE.c) -xc $(OUTPUT_OPTION) $<
