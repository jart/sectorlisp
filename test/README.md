# sectorlisp test scripts

For best results, please resize your terminal to 80x25.

You can launch a test with the following command:

	make test1

_This is tested on Linux. The qemu.sh script requires qemu,cc,wc & nc._

## files

- test1.lisp contains basic tests
- eval10.lisp evaluator from [eval.c as of commit 1058c95][1]
- eval15.lisp evaluator from [eval.c as of commit 3b26982 (latest)][2]

[//]: links
[1]: https://github.com/jart/sectorlisp/blob/1058c959d80b7103514cd7e959dbd67b38f4400b/lisp.c
[2]: https://github.com/jart/sectorlisp/blob/3b26982d9c06cd43760604b6364df197a782333e/lisp.c
