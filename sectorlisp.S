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

.set g_mem,		%cx
.set g_token,		%cx
.set ZERO,		%bh
.set TWO,		%bx

.section .text,"ax",@progbits
.type	kNil,@object
.type	kT,@object
.type	kQuote,@object
.type	kCond,@object
.type	kAtom,@object
.type	kCar,@object
.type	kCdr,@object
.type	kCons,@object
.type	kEq,@object
.type	start,@function
.type	begin,@function
.globl	_start
.code16

_start:
kNil:	.asciz	"NIL"				# dec %si ; dec %cx ; dec %sp
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

begin:	xor	TWO,TWO
	push	%cs				# memory model ds=es=ss=cs
	pop	%ds
	push	%cs
	pop	%es
	push	%cs
	cli					# disable interrupts
	pop	%ss				# disable nonmaskable interrupts
	mov	TWO,%sp				# use null pointer as our stack
	sti					# enable interrupts
	cld					# direction forward
	inc	TWO
	inc	TWO
main:	mov	$0x8000,g_mem			# dl (g_look) is zero or cr
	call	GetToken
	call	GetObject
	xor	%dx,%dx
	call	Eval
	xchg	%ax,%si
	call	PrintObject
	mov	$'\r',%al
	call	PutChar
	jmp	main

GetToken:					# GetToken():al, dl is g_look
	mov	g_token,%di
1:	mov	%dl,%al
	cmp	$' ',%al
	jbe	2f
	stosb
	xchg	%ax,%si
2:	call	GetChar				# exchanges dx and ax
	cmp	$' ',%al
	jbe	1b
	cmp	$')',%al
	jbe	3f
	cmp	$')',%dl			# dl = g_look
	ja	1b
3:	movb	ZERO,(%di)
	xchg	%si,%ax
	ret

.PutObject:					# .PutObject(c:al,x:si)
	call	PutChar				# preserves si
PrintObject:					# PrintObject(x:si)
	test	%si,%si				# set sf=1 if cons
	jns	.PrintAtom			# jump if cons
.PrintList:
	mov	$'(',%al
2:	push	(TWO,%si)
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
	xor	%di,%di				# di = g_str
	xor	%al,%al
0:	push	%di				# save 1
1:	cmpsb
	jne	2f
	dec	%di
	scasb
	jne	1b
	jmp	5f
2:	pop	%si				# drop 1
	mov	g_token,%si
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

GetChar:					# GetChar→al:dl
	xor	%ax,%ax				# get keystroke
	int	$0x16				# keyboard service
						# ah is bios scancode
						# al is ascii character
PutChar:mov	$0x0e,%ah			# teletype output al cp437
	int	$0x10				# vidya service
	cmp	$'\r',%al			# don't clobber
	jne	1f				# xchg dx,ax and ret
	mov	$'\n',%al
	jmp	PutChar

////////////////////////////////////////////////////////////////////////////////

Pairlis:test	%di,%di				# Pairlis(x:di,y:si,a:dx):ax
	jz	1f				# jump if nil
	push	(TWO,%di)			# save 1 Cdr(x)
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
	push	(TWO,%di)			# save 1 Cdr(m)
	mov	(%di),%ax
	call	Eval
	pop	%di				# restore 1
	push	%ax				# save 2
	call	Evlis
#	jmp	xCons

xCons:	pop	%di				# restore 2
Cons:	xchg	%ax,%si				# Cons(m:di,a:ax):ax
	xchg	%di,%ax
	mov	g_mem,%di
	stosw
	xchg	%si,%ax
	stosw
	xchg	%di,g_mem
1:	xchg	%di,%ax
	ret

Gc:	cmp	%dx,%di				# Gc(x:di,mark:dx,aj:bp):ax
	jb	1b				# we assume immutable cells
	push	(TWO,%di)			# mark prevents negative gc
	mov	(%di),%di
	call	Gc
	pop	%di
	push	%ax
	call	Gc
	pop	%di
	call	Cons
	sub	%bp,%ax				# subtract adjustment
	ret

GetList:call	GetToken
	cmpb	$')',%al
	je	.retF
	call	GetObject
	push	%ax				# save 1
	call	GetList
	jmp	xCons

.Eval:	test	%ax,%ax				# Eval(e:ax,a:dx):ax w/o gc
	jns	Assoc				# lookup val if atom
	xchg	%ax,%si				# di = e
	lodsw					# ax = Car(e)
	cmp	$kQuote,%ax			# maybe CONS
	mov	(%si),%di			# di = Cdr(e)
	je	Car
	cmp	$kCond,%ax
	je	Evcon
.Ldflt2:push	%ax				# save 2
	call	Evlis				# preserves dx
	xchg	%ax,%si
	pop	%ax				# restore 2
#	jmp	Apply

Apply:	test	%ax,%ax				# Apply(fn:ax,x:si:a:dx):ax
	jns	.switch				# jump if atom
	xchg	%ax,%di				# di = fn
.lambda:mov	(TWO,%di),%di			# di = Cdr(fn)
	push	%di				# save 1
	mov	(%di),%di			# di = Cadr(fn)
	call	Pairlis
	xchg	%ax,%dx
	pop	%di				# restore 1
	jmp	.EvCadr
.ifCons:cmp	$kCons,%al
	mov	(TWO,%si),%si			# si = Cdr(x)
	lodsw					# si = Cadr(x)
	je	Cons
.isEq:	cmp	%di,%ax				# we know for certain it's eq
	jne	.retF
.retT:	mov	$kT,%ax
	ret
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
.dflt1:	push	%si				# save x
	call	Eval
	pop	%si				# restore x
	jmp	Apply

Cadr:	mov	(TWO,%di),%di			# contents of decrement register
	.byte	0x3C				# cmp §scasw,%al (nop next byte)
Cdr:	scasw					# increments our data index by 2
Car:	mov	(%di),%ax			# contents of address register!!
	ret

Assoc:	mov	%dx,%di				# Assoc(x:ax,y:dx):ax
	test	%dx,%dx				# nil test
	jz	.retF				# return nil if end of list
	mov	(TWO,%di),%dx			# we assume Eval() saved dx
	mov	(%di),%di
	scasw
	jne	Assoc
	jmp	Car

1:	mov	(TWO,%di),%di			# di = Cdr(c)
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

Eval:	push	%dx				# Eval(e:ax,a:dx):ax w/ gc
	push	g_mem				# with garbage collections
	call	.Eval				# discards non-result cons
	pop	%dx
	push	g_mem
	mov	g_mem,%bp
	sub	%dx,%bp
	xchg	%ax,%di
	call	Gc
	pop	%si
	mov	%dx,%di
	sub	%si,%cx				# cx = g_mem - si
	rep movsb
	mov	%di,g_mem
	pop	%dx
	ret

.type .sig,@object
.sig:
.fill 510 - (. - _start), 1, 0xce
.word 0xAA55
