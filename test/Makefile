test1: test1.lisp qemu.sh tcat
	sh qemu.sh test1.lisp
eval10: eval10.lisp qemu.sh tcat
	sh qemu.sh eval10.lisp
eval15: eval15.lisp qemu.sh tcat
	sh qemu.sh eval10.lisp
tcat: tcat.c
	$(CC) -o $@ $< -Wall

.PHONY: test1 eval10 eval15
