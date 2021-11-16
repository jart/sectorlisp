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

.set ATOM_NIL,		(kNil-kSymbols)<<1|1
.set ATOM_QUOTE,	(kQuote-kSymbols)<<1|1
.set ATOM_COND,		(kCond-kSymbols)<<1|1
.set ATOM_ATOM,		(kAtom-kSymbols)<<1|1
.set ATOM_CAR,		(kCar-kSymbols)<<1|1
.set ATOM_CDR,		(kCdr-kSymbols)<<1|1
.set ATOM_EQ,		(kEq-kSymbols)<<1|1
.set ATOM_CONS,		(kCons-kSymbols)<<1|1
.set ATOM_T,		(kT-kSymbols)<<1|1

.set g_str,		0x0
.set g_token,		%bp
.set g_mem,		%bp
.set ZERO,		%ch
.set ONE,		%cx
.set TWO,		%bx

.section .text,"ax",@progbits
.type	kSymbols,@object
.type	_begin,@function
.globl	_start
.code16

_start:
kSymbols:
kNil:	.asciz	"NIL"				# dec %si ; dec %cx ; dec %sp
kT:	.asciz	"T"				# add %dl,(%si) boot A:\ DL=0
	ljmp	$0x7c00>>4,$_begin		# cs = 0x7c00 is boot address
	.asciz	""				# x86 prog part of intern tab
kQuote:	.asciz	"QUOTE"
kCond:	.asciz	"COND"
kAtom:	.asciz	"ATOM"
kCar:	.asciz	"CAR"
kCdr:	.asciz	"CDR"
kCons:	.asciz	"CONS"
kEq:	.asciz	"EQ"				# needs to be last
_begin:	push	%cs				# memory model ds=es=ss=cs
	pop	%ds
	push	%cs
	pop	%es
	mov	$0x8000,%cx
	mov	%cx,g_mem
	mov	%cx,%di
	xor	%ax,%ax
	cld					# clear direction flag
	rep stosb				# memset(0x8000,0,0x8000)
	push	%ds				# cx is now zero
	cli					# disable interrupts
	pop	%ss				# disable nonmaskable interrupts
	mov	%ax,%sp				# use null pointer as our stack
	sti					# enable interrupts
	inc	ONE				# ++cx
	mov	ONE,TWO
	inc	TWO
main:	mov	$'\n',%dl
	call	GetToken
	call	GetObject
	mov	ONE,%dx				# dx = NIL
	call	Eval
	call	PrintObject
	mov	$'\r',%al
	call	PutChar
	jmp	main

GetToken:					# GetToken():al, dl is g_look
	mov	g_token,%di
	mov	%di,%si
1:	mov	%dl,%al
	cmp	$' ',%al
	jbe	2f
	stosb
	xchg	%ax,%si
2:	call	GetChar
	xchg	%ax,%dx				# dl = g_look
	cmp	$' ',%al
	jbe	1b
	cmp	$')',%al
	jbe	3f
	cmp	$')',%dl
	ja	1b
3:	movb	ZERO,(%di)
	xchg	%si,%ax
	ret

.PutObject:					# .PutObject(c:al,x:di)
	call	PutChar				# preserves di
	xchg	%di,%ax
#	jmp	PrintObject

PrintObject:					# PrintObject(x:ax)
	test	$1,%al
	xchg	%ax,%di
	jz	.PrintList
.PrintAtom:
	shr	%di
	mov	%di,%si				# lea g_str(%di),%si
.PrintString:					# nul-terminated in si
	lodsb
	test	%al,%al
	jz	.ret				# -> ret
	call	PutChar
	jmp	.PrintString
.PrintList:
	mov	$'(',%al
2:	push	(TWO,%di)			# save 1 Cdr(x)
	mov	(%di),%di			# di = Car(x)
	call	.PutObject
	pop	%ax				# restore 1
	cmp	ONE,%ax
	je	4f
	test	$1,%al
	xchg	%ax,%di
	mov	$' ',%al
	jz	2b
	mov	$249,%al			# bullet (A∙B)
	call	.PutObject
4:	mov	$')',%al
	jmp	PutChar

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
//	add	$-g_str,%ax
	add	%ax,%ax				# ax = 2 * ax
	inc	%ax				# + 1
.ret:	ret

GetChar:
	xor	%ax,%ax				# get keystroke
	int	$0x16				# keyboard service
						# ah is bios scancode
						# al is ascii character
PutChar:
	push	%bp				# original ibm pc scroll up bug
	mov	$0x0e,%ah			# teletype output al cp437
	int	$0x10				# vidya service
	pop	%bp				# preserves al
	cmp	$'\r',%al			# don't clobber stuff
	jne	.ret
	mov	$'\n',%al
	jmp	PutChar				# bx volatile

////////////////////////////////////////////////////////////////////////////////

Pairlis:cmp	ONE,%di				# Pairlis(x:di,y:si,a:dx):ax
	je	1f				# it's zip() basically
	push	(TWO,%di)			# save 1 Cdr(x)
	lodsw
	push	(%si)				# save 2 Cdr(y)
	mov	(%di),%di
	call	Cons				# preserves dx
	pop	%si				# restore 2
	pop	%di				# restore 1
	push	%ax				# save 3
	call	Pairlis
	pop	%di				# restore 3
	jmp	Cons				# can be inlined here
1:	xchg	%dx,%ax
	ret

Evlis:	cmp	ONE,%di				# Evlis(m:di,a:dx):ax
	je	1f
	push	(TWO,%di)			# save 1 Cdr(m)
	mov	(%di),%ax
	push	%dx				# save a
	call	Eval
	pop	%dx				# restore a
	pop	%di				# restore 1
	push	%ax				# save 2
	call	Evlis

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

GetList:call	GetToken
	cmpb	$')',%al
	je	.retF
	call	GetObject
	push	%ax				# save 1
	call	GetList
	jmp	xCons

1:	mov	(TWO,%di),%di			# di = Cdr(c)
Evcon:	push	%di				# save c
	mov	(%di),%si			# di = Car(c)
	lodsw					# ax = Caar(c)
	push	%dx				# save a
	call	Eval
	pop	%dx				# restore a
	pop	%di				# restore c
	cmp	ONE,%ax
	jz	1b
	mov	(%di),%di			# di = Car(c)
.EvCadr:call	Cadr				# ax = Cadar(c)
#	jmp	Eval

Eval:	test	$1,%al				# Eval(e:ax,a:dx):ax
	jnz	Assoc				# lookup val if atom
	xchg	%ax,%si				# di = e
	lodsw					# ax = Car(e)
	cmp	$ATOM_QUOTE,%ax			# maybe CONS
	mov	(%si),%di			# di = Cdr(e)
	je	Car
	cmp	$ATOM_COND,%ax
	je	Evcon
.Ldflt2:push	%ax				# save 2
	call	Evlis				# preserves dx
	xchg	%ax,%si
	pop	%ax				# restore 2
#	jmp	Apply

Apply:	test	$1,%al				# Apply(fn:ax,x:si:a:dx):ax
	jnz	.switch
	xchg	%ax,%di				# di = fn
.lambda:mov	(TWO,%di),%di			# di = Cdr(fn)
	push	%di				# save 1
	mov	(%di),%di			# di = Cadr(fn)
	call	Pairlis
	xchg	%ax,%dx
	pop	%di				# restore 1
	jmp	.EvCadr
.ifCons:cmp	$ATOM_CONS,%al
	mov	(TWO,%si),%si			# si = Cdr(x)
	lodsw					# si = Cadr(x)
	je	Cons
.isEq:	cmp	%di,%ax
	jne	.retF
.retT:	mov	$ATOM_T,%al			# ax = ATOM_T
	ret
.switch:cmp	$ATOM_EQ,%ax			# eq is last builtin atom
	ja	.dflt1				# ah is zero if not above
	mov	(%si),%di			# di = Car(x)
.ifCar:	cmp	$ATOM_CAR,%al
	je	Car
.ifCdr:	cmp	$ATOM_CDR,%al
	je	Cdr
.ifAtom:cmp	$ATOM_ATOM,%al
	jne	.ifCons
	test	ONE,%di
	jnz	.retT
.retF:	mov	ONE,%ax				# ax = ATOM_NIL
	ret
.dflt1:	push	%si				# save x
	push	%dx				# save a
	call	Eval
	pop	%dx				# restore a
	pop	%si				# restore x
	jmp	Apply

Cadr:	mov	(TWO,%di),%di			# contents of decrement register
	.byte	0x3C				# cmp §scasw,%al (nop next byte)
Cdr:	scasw					# increments our data index by 2
Car:	mov	(%di),%ax			# contents of address register!!
	ret

.Assoc:	mov	(TWO,%si),%dx			# dx = Cdr(y)
Assoc:	cmp	ONE,%dx				# Assoc(x:ax,y:dx):ax
	mov	%dx,%si
	je	.retF
	mov	(%si),%di			# bx = Car(y)
	cmp	%ax,(%di)			# (%di) = Caar(y)
	jne	.Assoc
	mov	(TWO,%di),%ax			# ax = Cdar(y)
	ret

.type .sig,@object;
.sig:
.fill 510 - (. - _start), 1, 0xce
.word 0xAA55
