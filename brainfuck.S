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

//	compliant brainfuck in 83 bytes
//	boots from bios on pc w/ 128kb+

	.code16
	.globl	_start
_start:	mov	$0x10000>>4,%di
	push	%di
	pop	%ds
	push	%di
	pop	%es
	mov	%si,%dx
Brain:	xor	%ax,%ax
	cmp	%dx,%si
	jb	Fuck
	int	$0x16
	mov	%al,(%si)
	inc	%dx
Fuck:	lodsb
        cbw
	cmp	$'>',%al
	je	Right
	cmp	$'<',%al
	je	Left
	sub	$'+',%al
	je	Inc
	dec	%ax
	je	Get
	dec	%ax
	je	Dec
	dec	%ax
	je	Put
	cmp	$']'-'.',%al
	je	Loop
	cmp	$'['-'.',%al
	jne	Brain
Do:	push	%si
Loop:	pop	%ax
	cmpb	%ah,(%di)
	jz	Brain
	push	%ax
	xchg	%ax,%si
	jmp	Brain
Inc:	incb	(%di)
	.byte	0x80
Dec:	decb	(%di)
	.byte	0x3C
Right:	inc	%di
	.byte	0x84
Put:	mov	$0x0e,%ah
	mov	(%di),%al
	int	$0x10
	jmp	Brain
Get:	int	$0x16
	stosb
Left:	dec	%di
	jmp	Brain
