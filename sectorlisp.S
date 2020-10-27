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

//	@fileoverview lisp.c built for real mode with manual tuning
//	binary footprint is approximately 960 bytes, about 40 bytes
//	of it is overhead needed to load the second 512-byte sector
//	so if we can find a way to reduce the code size another 400
//	bytes we can bootstrap the metacircular evaluator in an mbr

#define NIL		0
#define UNDEFINED	8
#define ATOM_T		30
#define ATOM_QUOTE	34
#define ATOM_ATOM	46
#define ATOM_EQ		56
#define ATOM_COND	62
#define ATOM_CAR	72
#define ATOM_CDR	80
#define ATOM_CONS	88
#define ATOM_LAMBDA	98

#define STR 0x4186

////////////////////////////////////////////////////////////////////////////////
.section .start,"ax",@progbits
.globl	main
.code16

main:	mov	$q.syntax,%bx
	mov	$32,%al
	mov	%al,32(%bx)
	mov	%al,13(%bx)
	mov	%al,10(%bx)
	movw	$10536,40(%bx)
	movb	$46,46(%bx)
	mov	$STR,%di
	mov	$kSymbols,%si
	mov	$57,%cx
	rep movsb
0:	call	GetChar
	mov	%ax,q.look
	call	GetToken
	call	GetObject
	xchg	%ax,%di
	mov	q.globals,%si
	call	Eval
	xchg	%ax,%di
	call	PrintObject
	mov	$kCrlf,%si
	call	PrintString
	jmp	0b

GetChar:xor	%ax,%ax				# get keystroke
	int	$0x16				# keyboard service
	xor	%ah,%ah				# ah is bios scancode
	push	%ax				# al is ascii character
	call	PutChar				# ax will have result
	cmp	$'\r',%al			# don't clobber stuff
	jne	1f
	mov	$'\n',%al
	call	PutChar
1:	pop	%ax
	ret

Cadr:	and	$-2,%di				# (object >> 1) * sizeof(word)
	mov	2(%di),%di			# contents of decrement register
	and	$-2,%di				# contents of address register
	mov	(%di),%ax
	ret

GetToken:
	xor	%bx,%bx
	mov	$q.syntax,%si
	mov	q.look,%ax
	mov	$q.token,%di
0:	mov	%al,%bl
	mov	(%bx,%si),%dl
	mov	%dl,%bl
	cmp	$0x20,%dl
	jne	1f
	call	GetChar
	jmp	0b
1:	test	%dl,%dl
	je	3f
	stosb
	call	GetChar
	jmp	4f
2:	test	%bl,%bl
	jne	4f
	stosb
	call	GetChar
	mov	%ax,%bx
	mov	(%bx,%si),%bl
3:	test	%al,%al
	jne	2b
4:	movb	$0,(%di)
	mov	%al,q.look
	ret

Assoc:	xchg	%si,%bx
0:	test	%bx,%bx
	je	2f
	and	$-2,%bx
	mov	(%bx),%si
	and	$-2,%si
	mov	(%si),%ax
	cmp	%di,%ax
	jne	1f
	mov	(%bx),%si
	and	$-2,%si
	mov	2(%si),%ax
	ret
1:	mov	2(%bx),%bx
	jmp	0b
2:	xor	%ax,%ax
	ret

GetObject:
	cmpb	$40,q.token
	je	GetList
	mov	$q.token,%di
//	𝑠𝑙𝑖𝑑𝑒

Intern:	mov	%di,%bx
	mov	$STR,%si
0:	lodsb
	test	%al,%al
	je	4f
	xor	%dx,%dx
1:	mov	%dx,%di
	mov	(%bx,%di),%cl
	cmp	%cl,%al
	jne	3f
	inc	%dx
	test	%al,%al
	jne	2f
	sub	%di,%si
	lea	-STR-1(%si),%ax
	jmp	6f
2:	lodsb
	jmp	1b
3:	test	%al,%al
	jz	0b
	lodsb
	jmp	3b
4:	lea	-1(%si),%di
	push	%di
	mov	%bx,%si
0:	lodsb
	stosb
	test	%al,%al
	jnz	0b
	pop	%ax
	sub	$STR,%ax
6:	shl	%ax
	ret

GetList:call	GetToken
	mov	q.token,%al
	cmp	$')',%al
	je	2f
	cmp	$'.',%al
	je	1f
	call	GetObject
	push	%ax			# save
	call	GetList
	xchg	%ax,%si
	pop	%di			# restore
	jmp	Cons
1:	call	GetToken
	jmp	GetObject
2:	xor	%ax,%ax
	ret

EvalCons:
	push	%dx			# save
	mov	2(%bx),%bx
	mov	%bx,%di
	call	Cadr
	xchg	%ax,%di
	mov	%bp,%si
	call	Eval
	mov	%bp,%si
	pop	%di			# restore
	push	%ax			# save
	call	Arg1
	pop	%si			# restore
	xchg	%ax,%di
	pop	%bp
//	jmp	Cons
//	𝑠𝑙𝑖𝑑𝑒

Cons:	mov	$q.index,%bx
	mov	(%bx),%ax
	addw	$2,(%bx)
	shl	%ax
	mov	%ax,%bx
	mov	%di,(%bx)
	mov	%si,2(%bx)
	or	$1,%ax
	ret

Bind:	test	%di,%di
	je	1f
	push	%bp
	and	$-2,%si
	and	$-2,%di
	mov	%di,%bp
	push	%dx				# save no. 1
	push	%si				# save no. 2
	mov	2(%si),%si
	mov	2(%di),%di
	call	Bind
	pop	%si				# rest no. 2
	mov	(%si),%di
	pop	%si				# rest no. 1
	push	%ax				# save no. 3
	call	Eval
	mov	%ds:(%bp),%di
	xchg	%ax,%si
	call	Cons
	pop	%si				# rest no. 3
	xchg	%ax,%di
	pop	%bp
	jmp	Cons
1:	xchg	%dx,%ax
	ret

PrintString:					# nul-terminated in si
0:	lodsb					# don't clobber bp, bx
	test	%al,%al
	je	1f
	call	PutChar
	jmp	0b
1:	ret

////////////////////////////////////////////////////////////////////////////////
.text

PrintObject:
	test	$1,%di
	jnz	1f
	shr	%di
	lea	STR(%di),%si
	jmp	PrintString
1:	push	%bx
	mov	%di,%bx
	mov	$40,%al
	call	PutChar
2:	and	$-2,%bx
	mov	(%bx),%di
	call	PrintObject
	mov	2(%bx),%bx
	test	%bx,%bx
	jz	4f
	test	$1,%bl
	jz	3f
	mov	$0x20,%al
	call	PutChar
	jmp	2b
3:	mov	$kDot,%si
	call	PrintString
	mov	%bx,%di
	call	PrintObject
4:	pop	%bx
	mov	$41,%al
//	jmp	PutChar
//	𝑠𝑙𝑖𝑑𝑒

PutChar:push	%bx				# don't clobber bp,bx,di,si,cx
	push	%bp				# original ibm pc scroll up bug
	mov	$7,%bx				# normal mda/cga style page zero
	mov	$0x0e,%ah			# teletype output al cp437
	int	$0x10				# vidya service
	pop	%bp				# preserves al
	pop	%bx
	ret

Arg1:	call	Cadr
	xchg	%ax,%di
//	jmp	Eval
//	𝑠𝑙𝑖𝑑𝑒

Eval:	push	%bp
	mov	%di,%dx
	mov	%si,%bp
0:	test	$1,%dl
	jne	1f
	xchg	%bp,%si
	xchg	%dx,%di
	pop	%bp
	jmp	Assoc
1:	mov	%dx,%bx
	and	$-2,%bx
	mov	(%bx),%ax
	test	$1,%al
	je	1f
	mov	(%bx),%di
	and	$-2,%di
	cmpw	$ATOM_LAMBDA,(%di)
	jne	EvalUndefined
	mov	2(%bx),%si
	mov	(%bx),%di
	push	%bx
	call	Cadr
	xchg	%ax,%di
	mov	%bp,%dx
	call	Bind
	xchg	%ax,%bp
	pop	%bx
	mov	(%bx),%bx
	mov	%bx,%di
	and	$-2,%di
	mov	2(%di),%di
	jmp	EvalCadrLoop
1:	mov	(%bx),%ax
	cmp	$ATOM_COND,%ax
	je	EvalCond
	jg	2f
	cmp	$ATOM_ATOM,%ax
	je	EvalAtom
	jg	1f
	test	%ax,%ax
	je	EvalUndefined
	cmp	$ATOM_QUOTE,%ax
	jne	EvalCall
	xchg	%dx,%di
	pop	%bp
	jmp	Cadr
1:	cmp	$ATOM_EQ,%ax
	jne	EvalCall
	push	%dx
	mov	2(%bx),%bx
	mov	%bx,%di
	call	Cadr
	xchg	%ax,%di
	mov	%bp,%si
	call	Eval
	mov	%bp,%si
	pop	%di			# restore
	push	%ax			# save
	call	Arg1
	pop	%dx			# restore
	cmp	%dx,%ax
	jmp	3f
EvalCdr:
	mov	%dx,%di
	mov	%bp,%si
	call	Arg1
	and	$-2,%ax
	xchg	%ax,%di
	mov	2(%di),%ax
	pop	%bp
	ret
EvalCond:
	mov	2(%bx),%bx
	and	$-2,%bx
	mov	(%bx),%di
	and	$-2,%di
	mov	(%di),%di
	mov	%bp,%si
	push	%bx				# save
	call	Eval
	pop	%bx				# restore
	test	%ax,%ax
	je	EvalCond
	mov	(%bx),%di
	jmp	EvalCadrLoop
2:	cmp	$ATOM_CDR,%ax
	je	EvalCdr
	cmp	$ATOM_CONS,%ax
	je	EvalCons
	cmp	$ATOM_CAR,%ax
	jne	EvalCall
	mov	%dx,%di
	mov	%bp,%si
	call	Arg1
	and	$-2,%ax
	xchg	%ax,%di
	mov	(%di),%ax
	jmp	9f
EvalAtom:
	mov	%bp,%si
	mov	%dx,%di
	call	Arg1
	test	$1,%al
3:	mov	$ATOM_T,%ax
	je	9f
	xor	%ax,%ax
	jmp	9f
EvalCall:
	mov	2(%bx),%cx
	mov	(%bx),%di
	mov	%bp,%si
	call	Assoc
	xchg	%cx,%si
	xchg	%ax,%di
	call	Cons
	jmp	1f
EvalCadrLoop:
	call	Cadr
1:	xchg	%ax,%dx
	jmp	0b
EvalUndefined:
	mov	$UNDEFINED,%ax
9:	pop	%bp
	ret

////////////////////////////////////////////////////////////////////////////////
.section .rodata,"a",@progbits

kDot:	.string	" . "
kCrlf:	.string	"\r\n"
kSymbols:
	.string	"NIL"
	.string	"*UNDEFINED"
	.string	"T"
	.string	"QUOTE"
	.string	"ATOM"
	.string	"EQ"
	.string	"COND"
	.string	"CAR"
	.string	"CDR"
	.string	"CONS"
	.string	"LAMBDA"
	.string	""
