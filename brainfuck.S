/*-*- mode:unix-assembly; indent-tabs-mode:t; tab-width:8; coding:utf-8     -*-│
│vi: set et ft=asm ts=8 tw=8 fenc=utf-8                                     :vi│
╞══════════════════════════════════════════════════════════════════════════════╡
│ Copyright 2021 Justine Alexandra Roberts Tunney                              │
│ Some size optimisations by Peter Ferrie                                      │
│                                                                              │
│ Permission to use, copy, modify, and/or distribute this software for         │
│ any purpose with or without fee is hereby granted, provided that the         │
│ above copyright notice and this permission notice appear in all copies.      │
│                                                                              │
│ THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL                │
│ WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED                │
│ WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE             │
│ AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL         │
│ DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR        │
│ PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER               │
│ TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR             │
│ PERFORMANCE OF THIS SOFTWARE.                                                │
╚─────────────────────────────────────────────────────────────────────────────*/

//	compliant brainf*#k in 99 bytes
//	++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++
//	..+++.>>.<-.<.+++.------.--------.>>+.>++.[]$

	.code16
	.globl	_start
_start:	mov	$0x7e00,%di
	push	%di
Load:	xor	%ax,%ax
	int	$0x16
	stosb
	cmp	$'[',%al
	je	Lsb
	cmp	$']',%al
	je	Rsb
	cmp	$'$',%al
	jne	Load
	pop	%si
Brain:	lodsb
        cbw
	mov	$0x0e,%bh
	mov	(%di),%bl
	sub	$'+',%al
	jz	Inc		# + 43
	dec	%ax
	jz	Get		# , 44
	dec	%ax
	jz	Dec		# - 45
	dec	%ax
	jz	Put		# . 46
	cmp	$'>'-'.',%al
	je	Right		# > 60 14
	cmp	$'<'-'.',%al
	je	Left		# < 62 16
	cmp	$']'-'.',%al
	je	Loop		# ] 91 45
	cmp	$'['-'.',%al
	jne	Brain		# [ 93 47
Do:	cmp	$1,%bl
	sbb	%bl,%bl
Loop:	test	%bl,%bl
	lodsw
	jz	Brain
	xchg	%ax,%si
	inc	%si
	inc	%si
	.byte	0x80
Inc:	incb	(%di)
	jmp	Brain
Get:	int	$0x16
	stosb
Left:	dec	%di
	.byte	0x80
Dec:	decb	(%di)
	.byte	0x3C
Right:	inc	%di
	.byte	0x84
Put:	xchg	%bx,%ax
	int	$0x10
	jmp	Brain
Rsb:	pop	%si
	mov	%di,(%si)
	xchg	%si,%ax
	.byte	0x3c
Lsb:	push	%di
	stosw
	jmp	Load

Sig:	.fill	510 - (. - _start), 1, 0xce
	.word	0xAA55
	.type	Sig,@object

