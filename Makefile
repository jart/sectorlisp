CFLAGS	?= -g
CFLAGS	+= -fno-pie
LDFLAGS	+= -no-pie  # -s -static -N

REALFLAGS =				\
	-Os				\
	-D__REAL_MODE__			\
	-wrapper ./realify.sh		\
	-ffixed-r8			\
	-ffixed-r9			\
	-ffixed-r10			\
	-ffixed-r11			\
	-ffixed-r12			\
	-ffixed-r13			\
	-ffixed-r14			\
	-ffixed-r15			\
	-mno-red-zone			\
	-fcall-used-rbx			\
	-fno-jump-tables		\
	-fno-shrink-wrap		\
	-fno-schedule-insns2		\
	-flive-range-shrinkage		\
	-fno-omit-frame-pointer		\
	-momit-leaf-frame-pointer	\
	-mpreferred-stack-boundary=3	\
	-fno-delete-null-pointer-checks

CLEANFILES =				\
	lisp				\
	lisp.o				\
	lisp.real.o			\
	sectorlisp.o			\
	start.o				\
	lisp.bin			\
	sectorlisp.bin			\
	lisp.bin.dbg			\
	sectorlisp.bin.dbg

lisp:	lisp.o

.PHONY:	all
all:	lisp				\
	lisp.bin			\
	lisp.bin.dbg			\
	sectorlisp.bin			\
	sectorlisp.bin.dbg

.PHONY:	clean
clean:;	$(RM) $(CLEANFILES)

lisp.bin.dbg: start.o lisp.real.o lisp.lds
sectorlisp.bin.dbg: start.o sectorlisp.o lisp.lds

start.o: start.S
lisp.o: lisp.c lisp.h
lisp.real.o: lisp.c lisp.h
sectorlisp.o: sectorlisp.S

%.real.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(REALFLAGS) -c -o $@ $<

%.bin.dbg:
	$(LD) $(LDFLAGS) -static -o $@ $(patsubst %.lds,-T %.lds,$^)

%.bin: %.bin.dbg
	objcopy -SO binary $< $@
