/*-*- mode:unix-assembly; indent-tabs-mode:t; tab-width:8; coding:utf-8     -*-│
│vi: set et ft=asm ts=8 tw=8 fenc=utf-8                                     :vi│
╞══════════════════════════════════════════════════════════════════════════════╡
│ Copyright 2020 Justine Alexandra Roberts Tunney                              │
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
.section .start,"ax",@progbits
.globl	_start
.code16

_start:	jmp	1f				# some bios scan for short jump
1:	ljmp	$0x600>>4,$_begin		# end of bios data roundup page

_begin:	push	%cs				# memory model cs=ds=es = 0x600
	pop	%ds
	push	%cs
	pop	%es
	mov	$0x70000>>4,%ax			# last 64k of first 480k memory
	cli					# create stack in higher memory
	mov	%ax,%ss				# carefully avoids i8086 errata
	xor	%sp,%sp
	sti
	cld
	xor	%ax,%ax
	xor	%di,%di
	mov	$0x7c00-0x600,%cx
	rep stosb				# clears our bss memory
	xchg	%di,%bx				# start buffer at 07c00
	inc	%cx				# start at first sector
	xor	%dh,%dh				# drive dl head zero
	mov	$0x0200+v_sectors,%ax		# read sectors
	int	$0x13				# disk service
//	𝑠𝑙𝑖𝑑𝑒

	.section .yoink
	nopw	main
