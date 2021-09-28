/*-*- mode:c;indent-tabs-mode:nil;c-basic-offset:2;tab-width:8;coding:utf-8 -*-│
│vi: set net ft=c ts=2 sts=2 sw=2 fenc=utf-8                                :vi│
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
#include "lisp.h"

#define RETRO  1  // auto capitalize input
#define DELETE 1  // allow backspace to rub out symbol
#define QUOTES 1  // allow 'X shorthand (QUOTE X)
#define PROMPT 1  // show repl prompt
#define WORD   short
#define WORDS  8192

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § LISP Machine                                        ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

#define ATOM 1
#define CONS 0

#define NIL         (ATOM | 0)
#define UNDEFINED   (ATOM | 8)
#define ATOM_T      (ATOM | 30)
#define ATOM_QUOTE  (ATOM | 34)
#define ATOM_COND   (ATOM | 46)
#define ATOM_ATOM   (ATOM | 56)
#define ATOM_CAR    (ATOM | 66)
#define ATOM_CDR    (ATOM | 74)
#define ATOM_CONS   (ATOM | 82)
#define ATOM_EQ     (ATOM | 92)
#define ATOM_LAMBDA (ATOM | 98)

#define VALUE(x) ((x) >> 1)

struct Lisp {
  WORD mem[WORDS];
  unsigned char syntax[256];
  WORD look;
  WORD globals;
  WORD index;
  char token[128];
  char str[WORDS];
};

_Static_assert(sizeof(struct Lisp) <= 0x7c00 - 0x600,
               "LISP Machine too large for real mode");

_Alignas(char) const char kSymbols[] = "NIL\0"
                                       "*UNDEFINED\0"
                                       "T\0"
                                       "QUOTE\0"
                                       "COND\0"
                                       "ATOM\0"
                                       "CAR\0"
                                       "CDR\0"
                                       "CONS\0"
                                       "EQ\0"
                                       "LAMBDA";

#ifdef __REAL_MODE__
static struct Lisp *const q;
#else
static struct Lisp q[1];
#endif

static void Print(long);
static WORD GetList(void);
static WORD GetObject(void);
static void PrintObject(long);
static WORD Eval(WORD, WORD);

static void SetupSyntax(void) {
  unsigned char *syntax = q->syntax;
  asm("" : "+bSD"(syntax));
  syntax[' '] = ' ';
  syntax['\r'] = ' ';
  syntax['\n'] = ' ';
  syntax['('] = '(';
  syntax[')'] = ')';
  syntax['.'] = '.';
#if QUOTES
  syntax['\''] = '\'';
#endif
}

static void SetupBuiltins(void) {
  CopyMemory(q->str, kSymbols, sizeof(kSymbols));
}

static inline WORD Car(long x) {
  return PEEK_ARRAY(q, mem, VALUE(x), 0);
}

static inline WORD Cdr(long x) {
  return PEEK_ARRAY(q, mem, VALUE(x), 1);
}

static WORD Set(long i, long k, long v) {
  POKE_ARRAY(q, mem, VALUE(i), 0, k);
  POKE_ARRAY(q, mem, VALUE(i), 1, v);
  return i;
}

static WORD Cons(WORD car, WORD cdr) {
  int i, cell;
  i = q->index;
  POKE_ARRAY(q, mem, i, 0, car);
  POKE_ARRAY(q, mem, i, 1, cdr);
  q->index = i + 2;
  cell = OBJECT(CONS, i);
  return cell;
}

static char *StpCpy(char *d, char *s) {
  char c;
  do {
    c = LODS(s);  // a.k.a. c = *s++
    STOS(d, c);   // a.k.a. *d++ = c
  } while (c);
  return d;
}

static WORD Intern(char *s) {
  int j, cx;
  char c, *z, *t;
  z = q->str;
  c = LODS(z);
  while (c) {
    for (j = 0;; ++j) {
      if (c != PEEK(s, j, 0)) {
        break;
      }
      if (!c) {
        return OBJECT(ATOM, z - q->str - j - 1);
      }
      c = LODS(z);
    }
    while (c) c = LODS(z);
    c = LODS(z);
  }
  --z;
  StpCpy(z, s);
  return OBJECT(ATOM, SUB((long)z, q->str));
}

static unsigned char XlatSyntax(unsigned char b) {
  return PEEK_ARRAY(q, syntax, b, 0);
}

static void PrintString(char *s) {
  char c;
  for (;;) {
    if (!(c = PEEK(s, 0, 0))) break;
    PrintChar(c);
    ++s;
  }
}

static int GetChar(void) {
  int c;
  c = ReadChar();
#if RETRO
  if (c >= 'a') {
    CompilerBarrier();
    if (c <= 'z') c -= 'a' - 'A';
  }
#endif
#if DELETE
  if (c == '\b') return c;
#endif
  PrintChar(c);
  if (c == '\r') PrintChar('\n');
  return c;
}

static void GetToken(void) {
  char *t;
  unsigned char b, x;
  b = q->look;
  t = q->token;
  for (;;) {
    x = XlatSyntax(b);
    if (x != ' ') break;
    b = GetChar();
  }
  if (x) {
    STOS(t, b);
    b = GetChar();
  } else {
    while (b && !x) {
      if (!DELETE || b != '\b') {
        STOS(t, b);
      } else if (t > q->token) {
        PrintString("\b \b");
        if (t > q->token) --t;
      }
      b = GetChar();
      x = XlatSyntax(b);
    }
  }
  STOS(t, 0);
  q->look = b;
}

static WORD ConsumeObject(void) {
  GetToken();
  return GetObject();
}

static WORD Cadr(long x) {
  return Car(Cdr(x));  // ((A B C D) (E F G) H I) → (E F G)
}

static WORD List(long x, long y) {
  return Cons(x, Cons(y, NIL));
}

static WORD Quote(long x) {
  return List(ATOM_QUOTE, x);
}

static WORD GetQuote(void) {
  return Quote(ConsumeObject());
}

static WORD AddList(WORD x) {
  return Cons(x, GetList());
}

static WORD GetList(void) {
  GetToken();
  switch (*q->token & 0xFF) {
    default:
      return AddList(GetObject());
    case ')':
      return NIL;
    case '.':
      return ConsumeObject();
#if QUOTES
    case '\'':
      return AddList(GetQuote());
#endif
  }
}

static WORD GetObject(void) {
  switch (*q->token & 0xFF) {
    default:
      return Intern(q->token);
    case '(':
      return GetList();
#if QUOTES
    case '\'':
      return GetQuote();
#endif
  }
}

static WORD ReadObject(void) {
  q->look = GetChar();
  GetToken();
  return GetObject();
}

static WORD Read(void) {
  return ReadObject();
}

static void PrintAtom(long x) {
  PrintString(q->str + VALUE(x));
}

static void PrintList(long x) {
#if QUOTES
  if (Car(x) == ATOM_QUOTE) {
    PrintChar('\'');
    PrintObject(Cadr(x));
    return;
  }
#endif
  PrintChar('(');
  PrintObject(Car(x));
  while ((x = Cdr(x))) {
    if (!ISATOM(x)) {
      PrintChar(' ');
      PrintObject(Car(x));
    } else {
      PrintString(" . ");
      PrintObject(x);
      break;
    }
  }
  PrintChar(')');
}

static void PrintObject(long x) {
  if (ISATOM(x)) {
    PrintAtom(x);
  } else {
    PrintList(x);
  }
}

static void Print(long i) {
  PrintObject(i);
  PrintString("\r\n");
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § Bootstrap John McCarthy's Metacircular Evaluator    ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

static WORD Caar(long x) {
  return Car(Car(x));  // ((A B C D) (E F G) H I) → A
}

static WORD Cdar(long x) {
  return Cdr(Car(x));  // ((A B C D) (E F G) H I) → (B C D)
}

static WORD Cadar(long x) {
  return Cadr(Car(x));  // ((A B C D) (E F G) H I) → B
}

static WORD Caddr(long x) {
  return Cadr(Cdr(x));  // ((A B C D) (E F G) H I) → H
}

static WORD Caddar(long x) {
  return Caddr(Car(x));  // ((A B C D) (E F G) H I) → C
}

static WORD Evcon(long c, long a) {
  return Eval(Caar(c), a) != NIL ? Eval(Cadar(c), a) : Evcon(Cdr(c), a);
}

static WORD Assoc(long x, long a) {
  return a != NIL ? Caar(a) == x ? Cdar(a) : Assoc(x, Cdr(a)) : NIL;
}

static WORD Pairlis(WORD x, WORD y, WORD a) {
  if (x == NIL)
    return a;
  WORD di = Cons(Car(x), Car(y));
  WORD si = Pairlis(Cdr(x), Cdr(y), a);
  return Cons(di, si); // Tail-Modulo-Cons
}

static WORD Evlis(WORD m, WORD a) {
  if (m == NIL)
    return NIL;
  WORD di = Eval(Car(m), a);
  WORD si = Evlis(Cdr(m), a);
  return Cons(di, si);
}

static WORD Apply(WORD fn, WORD x, WORD a) {
  if (ISATOM(fn)) {
    switch (fn) {
    case NIL:
      return UNDEFINED;
    case ATOM_CAR:
      return Caar(x);
    case ATOM_CDR:
      return Cdar(x);
    case ATOM_ATOM:
      return ISATOM(Car(x)) ? ATOM_T : NIL;
    case ATOM_CONS:
      return Cons(Car(x), Cadr(x));
    case ATOM_EQ:
      return Car(x) == Cadr(x) ? ATOM_T : NIL;
    default:
      return Apply(Eval(fn, a), x, a);
    }
  }

  if (Car(fn) == ATOM_LAMBDA) {
    WORD t1 = Cdr(fn);
    WORD si = Pairlis(Car(t1), x, a);
    WORD ax = Cadr(t1);
    return Eval(ax, si);
  }

  return UNDEFINED;
}

static WORD Eval(WORD e, WORD a) {
  if (ISATOM(e))
    return Assoc(e, a);

  WORD ax = Car(e);
  if (ISATOM(ax)) {
    if (ax == ATOM_QUOTE)
      return Cadr(e);
    if (ax == ATOM_COND)
      return Evcon(Cdr(e), a);
    if (ax == ATOM_LAMBDA)
      return e;
  }

  return Apply(ax, Evlis(Cdr(e), a), a);
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § User Interface                                      ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

void Repl(void) {
  for (;;) {
#if PROMPT
    PrintString("* ");
#endif
    Print(Eval(Read(), q->globals));
  }
}

int main(int argc, char *argv[]) {
  RawMode();
  SetupSyntax();
  SetupBuiltins();
#if PROMPT
  PrintString("THE LISP CHALLENGE V1\r\n"
              "VISIT GITHUB.COM/JART\r\n");
#endif
  Repl();
  return 0;
}
