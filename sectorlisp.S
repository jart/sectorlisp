/*-*- mode:unix-assembly; indent-tabs-mode:t; tab-width:8; coding:utf-8     -*-│
│vi: set et ft=asm ts=8 tw=8 fenc=utf-8                                     :vi│
╞══════════════════════════════════════════════════════════════════════════════╡
│ Copyright 2020 Justine Alexandra Roberts Tunney                              │
│ Copyright 2021 Alain Greppin                                                 │
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

// LISP meta-circular evaluator in a MBR
// Compatible with the original hardware

	.code16
	.globl	_start
_start:	.asciz	"NIL"				# dec %si ; dec %cx ; dec %sp
kT:	.asciz	"T"				# add %dl,(%si) boot A:\ DL=0
start:	ljmp	$0x7c00>>4,$begin		# cs = 0x7c00 is boot address
	.asciz	""
kQuote:	.asciz	"QUOTE"
kCond:	.asciz	"COND"
kAtom:	.asciz	"ATOM"				# ordering matters
kCar:	.asciz	"CAR"				# ordering matters
kCdr:	.asciz	"CDR"				# ordering matters
kCons:	.asciz	"CONS"				# ordering matters
kEq:	.asciz	"EQ"				# needs to be last

begin:	push	%cs				# that means ss = ds = es = cs
	pop	%ds				# noting ljmp set cs to 0x7c00
	push	%cs				# that's the bios load address
	pop	%es				# therefore NULL points to NUL
	push	%cs				# terminated NIL string above!
	pop	%ss				# errata exists but don't care
	xor	%sp,%sp				# use highest address as stack
	mov	$2,%bx
main:	mov	$0x8000,%cx			# dl (g_look) is zero or cr
	call	GetToken
	call	GetObject
	call	Eval
	xchg	%ax,%si
	call	PrintObject
	mov	$'\r',%al
	call	PutChar
	jmp	main

GetToken:					# GetToken():al, dl is g_look
	mov	%cx,%di
1:	mov	%dl,%al
	cmp	$' ',%al
	jbe	2f
	stosb
	xchg	%ax,%bp
2:	call	GetChar				# exchanges dx and ax
	cmp	$' ',%al
	jbe	1b
	cmp	$')',%al
	jbe	3f
	cmp	$')',%dl			# dl = g_look
	ja	1b
3:	movb	%bh,(%di)			# bh is zero
	xchg	%bp,%ax
	ret

.PutObject:					# .PutObject(c:al,x:si)
	call	PutChar				# preserves si
PrintObject:					# PrintObject(x:si)
	test	%si,%si				# set sf=1 if cons
	jns	.PrintAtom			# jump if cons
.PrintList:
	mov	$'(',%al
2:	push	(%bx,%si)
	mov	(%si),%si
	call	.PutObject
	mov	$' ',%al
	pop	%si				# restore 1
	test	%si,%si
	js	2b				# jump if cons
	jz	4f				# jump if nil
	mov	$249,%al			# bullet (A∙B)
	call	.PutObject
4:	mov	$')',%al
	jmp	PutChar
.PrintString:					# nul-terminated in si
	call	PutChar
.PrintAtom:
	lodsb
	test	%al,%al				# test for nul terminator
	jnz	.PrintString			# -> ret
	ret

GetObject:					# called just after GetToken
	cmpb	$'(',%al
	je	GetList
.Intern:
	mov	%cx,%si
	xor	%di,%di
	xor	%al,%al
0:	push	%di				# save 1
1:	cmpsb
	jne	2f
	dec	%di
	scasb
	jne	1b
	jmp	5f
2:	pop	%bp				# drop 1
	mov	%cx,%si
3:	scasb
	jne	3b
	cmp	(%di),%al
	jne	0b
	push	%di				# StpCpy
4:	movsb
	dec	%di
	scasb
	jnz	4b
5:	pop	%ax				# restore 1
.ret:	ret

GetChar:xor	%ax,%ax				# GetChar→al:dl
	int	$0x16				# get keystroke
PutChar:mov	$0x0e,%ah			# prints CP-437
	int	$0x10				# vidya service
	cmp	$'\r',%al			# don't clobber
	jne	1f				# look xchg ret
	mov	$'\n',%al
	jmp	PutChar

////////////////////////////////////////////////////////////////////////////////

Pairlis:test	%di,%di				# Pairlis(x:di,y:si,a:dx):ax
	jz	1f				# jump if nil
	push	(%bx,%di)			# save 1 Cdr(x)
	lodsw
	push	(%si)				# save 2 Cdr(y)
	mov	(%di),%di
	call	Cons				# preserves dx
	pop	%si				# restore 2
	pop	%di				# restore 1
	push	%ax				# save 3
	call	Pairlis
	jmp	xCons				# can be inlined here
1:	xchg	%dx,%ax
	ret

Evlis:	test	%di,%di				# Evlis(m:di,a:dx):ax
	jz	1f				# jump if nil
	push	(%bx,%di)			# save 1 Cdr(m)
	mov	(%di),%ax
	call	Eval
	pop	%di				# restore 1
	push	%ax				# save 2
	call	Evlis
#	jmp	xCons

xCons:	pop	%di				# restore 2
Cons:	xchg	%di,%cx				# Cons(m:di,a:ax):ax
	mov	%cx,(%di)
	mov	%ax,(%bx,%di)
	lea	4(%di),%cx
1:	xchg	%di,%ax
	ret

Gc:	cmp	%dx,%di				# Gc(x:di,A:dx,B:si):ax
	jb	1b				# we assume immutable cells
	push	(%bx,%di)			# mark prevents negative gc
	mov	(%di),%di
	call	Gc
	pop	%di
	push	%ax
	call	Gc
	pop	%di
	call	Cons
	sub	%si,%ax				# ax -= C - B
	add	%dx,%ax
	ret

GetList:call	GetToken
	cmpb	$')',%al
	je	.retF
	call	GetObject
	push	%ax				# popped by xCons
	call	GetList
	jmp	xCons

.dflt1:	push	%si				# save x
	call	Eval
	pop	%si				# restore x
#	jmp	Apply

Apply:	test	%ax,%ax				# Apply(fn:ax,x:si:a:dx):ax
	jns	.switch				# jump if atom
	xchg	%ax,%di				# di = fn
.lambda:mov	(%bx,%di),%di			# di = Cdr(fn)
	push	%di				# save 1
	mov	(%di),%di			# di = Cadr(fn)
	call	Pairlis
	xchg	%ax,%dx
	pop	%di				# restore 1
	jmp	.EvCadr
.switch:cmp	$kEq,%ax			# eq is last builtin atom
	ja	.dflt1				# ah is zero if not above
	mov	(%si),%di			# di = Car(x)
.ifCar:	cmp	$kCar,%al
	je	Car
.ifCdr:	cmp	$kCdr,%al
	je	Cdr
.ifAtom:cmp	$kAtom,%al
	jne	.ifCons
	test	%di,%di				# test if atom
	jns	.retT
.retF:	xor	%ax,%ax				# ax = nil
	ret
.ifCons:cmp	$kCons,%al
	mov	(%bx,%si),%si			# si = Cdr(x)
	lodsw					# si = Cadr(x)
	je	Cons
.isEq:	cmp	%di,%ax				# we know for certain it's eq
	jne	.retF
.retT:	mov	$kT,%ax
	ret

Cadr:	mov	(%bx,%di),%di			# contents of decrement register
	.byte	0x3C				# cmp §scasw,%al (nop next byte)
Cdr:	scasw					# increments our data index by 2
Car:	mov	(%di),%ax			# contents of address register!!
2:	ret

Assoc:	mov	%dx,%si				# Assoc(x:ax,y:dx):ax
1:	mov	(%si),%di
	mov	(%bx,%si),%si
	scasw
	jne	1b
	jmp	Car

1:	mov	(%bx,%di),%di			# di = Cdr(c)
Evcon:	push	%di				# save c
	mov	(%di),%si			# di = Car(c)
	lodsw					# ax = Caar(c)
	call	Eval
	pop	%di				# restore c
	test	%ax,%ax				# nil test
	jz	1b
	mov	(%di),%di			# di = Car(c)
.EvCadr:call	Cadr				# ax = Cadar(c)
#	jmp	Eval

Eval:	test	%ax,%ax				# Eval(e:ax,a:dx):ax
	jz	1f
	jns	Assoc				# lookup val if atom
	xchg	%ax,%si				# di = e
	lodsw					# ax = Car(e)
	cmp	$kQuote,%ax			# maybe CONS
	mov	(%si),%di			# di = Cdr(e)
	je	Car
	cmp	$kCond,%ax
	je	Evcon				# ABC Garbage Collector
	push	%dx				# save a
	push	%cx				# save A
	push	%ax
	call	Evlis
	xchg	%ax,%si
	pop	%ax
	call	Apply
	pop	%dx				# restore A
	mov	%cx,%si				# si = B
	xchg	%ax,%di
	call	Gc
	mov	%dx,%di				# di = A
	sub	%si,%cx				# cx = C - B
	rep movsb
	mov	%di,%cx				# cx = A + (C - B)
	pop	%dx				# restore a
1:	ret

.sig:	.fill	510 - (. - _start), 1, 0xce
	.word	0xAA55
	.type	.sig,@object
	.type	kQuote,@object
	.type	kCond,@object
	.type	kAtom,@object
	.type	kCar,@object
	.type	kCdr,@object
	.type	kCons,@object
	.type	kEq,@object
