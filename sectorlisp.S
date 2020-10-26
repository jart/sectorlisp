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

/	@fileoverview lisp.c built for real mode with manual tuning
/	binary footprint is approximately 960 bytes, about 40 bytes
/	of it is overhead needed to load the second 512-byte sector
/	so if we can find a way to reduce the code size another 400
/	bytes we can bootstrap the metacircular evaluator in an mbr

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

#define SYNTAX		0x4000
#define LOOK		0x4100
#define GLOBALS		0x4102
#define INDEX		0x4104
#define TOKEN		0x4106
#define STR		0x41c8

////////////////////////////////////////////////////////////////////////////////
.section .start,"ax",@progbits
.globl	main
.code16

main:	mov	$SYNTAX,%bx
	movb	$32,32(%bx)
	movb	$32,13(%bx)
	movb	$32,10(%bx)
	movw	$10536,40(%bx)
	movb	$46,46(%bx)
	mov	$STR,%di
	mov	$kSymbols,%si
	mov	$57,%cx
	rep movsb
0:	call	GetChar
	mov	%ax,LOOK
	call	GetToken
	call	GetObject
	xchg	%ax,%di
	mov	GLOBALS,%si
	call	Eval
	xchg	%ax,%di
	call	PrintObject
	mov	$kCrlf,%di
	call	PrintString
	jmp	0b

PutChar:push	%bx
	push	%bp				# original ibm pc scroll up bug
	mov	$0x0007,%bx			# normal mda/cga style page zero
	xchg	%di,%ax				# character to display
	mov	$0x0E,%ah			# teletype output
	int	$0x10				# vidya service
	pop	%bp				# result dil→al
	pop	%bx
	ret

GetChar:xor	%ax,%ax				# get keystroke
	int	$0x16				# keyboard service
	xor	%ah,%ah				# ah is bios scancode
	push	%ax				# al is ascii character
	xchg	%ax,%di				# result is ax
	call	PutChar
	cmp	$'\r,%al
	jne	1f
	mov	$'\n,%di
	call	PutChar
1:	pop	%ax
	ret

PrintString:
	mov	%di,%dx
0:	mov	%dx,%di
	mov	(%di),%al
	test	%al,%al
	je	1f
	xchg	%ax,%di
	call	PutChar
	inc	%dx
	jmp	0b
1:	ret

GetToken:
	xor	%bx,%bx
	mov	$SYNTAX,%si
	mov	LOOK,%ax
	mov	$TOKEN,%cx
0:	mov	%al,%bl
	mov	(%bx,%si),%dl
	mov	%dl,%bl
	cmp	$0x20,%dl
	jne	1f
	call	GetChar
	jmp	0b
1:	test	%dl,%dl
	je	3f
	xchg	%cx,%di
	stosb
	xchg	%di,%cx
	call	GetChar
	jmp	4f
2:	test	%bl,%bl
	jne	4f
	xchg	%cx,%di
	stosb
	xchg	%di,%cx
	call	GetChar
	mov	%ax,%bx
	mov	(%bx,%si),%bl
3:	test	%al,%al
	jne	2b
4:	mov	%cx,%di
	movb	$0,(%di)
	mov	%al,LOOK
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
	cmpb	$40,TOKEN
	je	1f
	mov	$TOKEN,%di
	jmp	Intern
1:	#jmp	GetList
/	𝑠𝑙𝑖𝑑𝑒

GetList:call	GetToken
	mov	TOKEN,%al
	cmp	$'),%al
	je	2f
	cmp	$'.,%al
	je	1f
	call	GetObject
	push	%ax
	call	GetList
	xchg	%ax,%si
	pop	%di
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
	mov	%ax,%di
	mov	%bp,%si
	call	Eval
	mov	%bp,%si
	pop	%di			# restore
	push	%ax			# save
	call	Arg1
	pop	%si			# restore
	xchg	%ax,%di
	pop	%bp
/	jmp	Cons
/	𝑠𝑙𝑖𝑑𝑒

Cons:	mov	$INDEX,%bx
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
	mov	%sp,%bp
	push	%dx
	push	%dx
	xchg	%si,%bx
	and	$-2,%bx
	and	$-2,%di
	mov	%di,-4(%bp)
	mov	2(%bx),%si
	mov	2(%di),%di
	push	%bx				# save no. 1
	call	Bind
	pop	%bx				# rest no. 1
	push	%ax				# save no. 2
	mov	(%bx),%bx
	mov	%bx,%di
	mov	-2(%bp),%si
	call	Eval
	mov	-4(%bp),%di
	mov	(%di),%di
	xchg	%ax,%si
	call	Cons
	pop	%si				# rest no. 2
	xchg	%ax,%di
	leave
	jmp	Cons
1:	xchg	%dx,%ax
	ret

EvalCdr:
	mov	%dx,%di
	mov	%bp,%si
	call	Arg1
	and	$-2,%ax
	mov	%ax,%di
	mov	2(%di),%ax
	pop	%bp
	ret

////////////////////////////////////////////////////////////////////////////////
.text

Cadr:	and	$-2,%di				# (object >> 1) * sizeof(word)
	mov	2(%di),%di			# contents of decrement register
	and	$-2,%di				# contents of address register
	mov	(%di),%ax
	ret

Arg1:	call	Cadr
	xchg	%ax,%di
	jmp	Eval

PrintObject:
	push	%bp
	mov	%di,%bp
	test	$1,%di
	setz	%al
	shr	%di
	test	%al,%al
	je	1f
	add	$STR,%di
	pop	%bp
	jmp	PrintString
1:	mov	$40,%di
	call	PutChar
2:	mov	%bp,%bx
	and	$-2,%bx
	mov	(%bx),%di
	call	PrintObject
	mov	%bp,%bx
	and	$-2,%bx
	mov	2(%bx),%bx
	mov	%bx,%bp
	test	%bx,%bx
	je	4f
	test	$1,%bl
	je	3f
	mov	$0x20,%di
	call	PutChar
	jmp	2b
3:	mov	$kDot,%di
	call	PrintString
	mov	%bp,%di
	call	PrintObject
4:	mov	$41,%di
	pop	%bp
	jmp	PutChar

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
	mov	(%bx),%ax
	and	$-2,%ax
	mov	%ax,%di
	mov	(%di),%ax
	cmp	$ATOM_LAMBDA,%ax
	jne	EvalUndefined
	mov	2(%bx),%si
	mov	(%bx),%di
	push	%bx
	call	Cadr
	mov	%si,%si
	mov	%ax,%di
	mov	%bp,%dx
	call	Bind
	mov	%ax,%bp
	pop	%bx
	mov	(%bx),%bx
	mov	%bx,%di
	and	$-2,%di
	mov	2(%di),%di
	jmp	8f
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
	mov	%ax,%di
	mov	%bp,%si
	call	Eval
	mov	%bp,%si
	pop	%di			# restore
	push	%ax			# save
	call	Arg1
	pop	%dx			# restore
	cmp	%dx,%ax
	jmp	3f
2:	cmp	$ATOM_CDR,%ax
	je	EvalCdr
	cmp	$ATOM_CONS,%ax
	je	EvalCons
	cmp	$ATOM_CAR,%ax
	jne	EvalCall
	mov	%bp,%si
	mov	%dx,%di
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
EvalCond:
	mov	2(%bx),%bx
	mov	%bx,%bx
	and	$-2,%bx
	mov	(%bx),%di
	push	%bx			# save
	and	$-2,%di
	mov	(%di),%di
	mov	%bp,%si
	call	Eval
	test	%ax,%ax
	pop	%bx			# restore
	je	EvalCond
	mov	(%bx),%bx
	mov	%bx,%di
	jmp	8f
EvalCall:
	mov	2(%bx),%cx
	mov	(%bx),%bx
	mov	%bx,%di
	mov	%bp,%si
	call	Assoc
	mov	%cx,%si
	mov	%ax,%di
	call	Cons
	jmp	1f
8:	call	Cadr
1:	mov	%ax,%dx
	jmp	0b
EvalUndefined:
	mov	$UNDEFINED,%ax
9:	pop	%bp
	ret

Intern:	push	%bp
	xchg	%di,%bx
	mov	$STR,%si
0:	lodsb
	test	%al,%al
	je	4f
	xor	%dx,%dx
1:	mov	%dx,%bp
	mov	%dx,%di
	mov	(%bx,%di),%cl
	cmp	%cl,%al
	jne	3f
	inc	%dx
	test	%al,%al
	jne	2f
	mov	%bp,%cx
	sub	%cx,%si
	lea	-STR-1(%si),%ax
	jmp	6f
2:	lodsb
	jmp	1b
3:	test	%al,%al
	je	0b
	lodsb
	jmp	3b
4:	lea	-1(%si),%dx
	mov	%dx,%di
	xchg	%bx,%si
0:	lodsb
	stosb
	test	%al,%al
	jnz	0b
	xchg	%dx,%ax
	sub	$STR,%ax
6:	shl	%ax
	pop	%bp
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
