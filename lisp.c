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
#include "bestline.h"

#ifndef __COSMOPOLITAN__
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#endif

#define QUOTES 1     /* allow 'X shorthand for (QUOTE X) */
#define FUNDEF 1     /* be friendly w/undefined behavior */
#define TRACE  0     /* prints Eval() arguments / result */

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § LISP Machine                                        ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

#define ATOM 0
#define CONS 1

#define ISATOM(x)   (~(x)&1)
#define VALUE(x)    ((x)>>1)
#define OBJECT(t,v) ((v)<<1|(t))

#define NIL         OBJECT(ATOM,0)
#define ATOM_T      OBJECT(ATOM,4)
#define ATOM_QUOTE  OBJECT(ATOM,6)
#define ATOM_COND   OBJECT(ATOM,12)
#define ATOM_ATOM   OBJECT(ATOM,17)
#define ATOM_CAR    OBJECT(ATOM,22)
#define ATOM_CDR    OBJECT(ATOM,26)
#define ATOM_CONS   OBJECT(ATOM,30)
#define ATOM_EQ     OBJECT(ATOM,35)
#define ATOM_LAMBDA OBJECT(ATOM,38)
#define UNDEFINED   OBJECT(ATOM,45)

struct Lisp {
  int mem[8192];
  unsigned char syntax[256];
  int look;
  int globals;
  int index;
  char token[128];
  char str[8192];
};

static const char kSymbols[] =
    "NIL\0"
    "T\0"
    "QUOTE\0"
    "COND\0"
    "ATOM\0"
    "CAR\0"
    "CDR\0"
    "CONS\0"
    "EQ\0"
    "LAMBDA\0"
#if FUNDEF
    "*UNDEFINED"
#endif
;

static struct Lisp q[1];

static void Print(int);
static int GetList(void);
static int GetObject(void);
static void PrintObject(int);
static int Eval(int, int);

static void SetupSyntax(void) {
  q->syntax[' '] = ' ';
  q->syntax['\r'] = ' ';
  q->syntax['\n'] = ' ';
  q->syntax['('] = '(';
  q->syntax[')'] = ')';
  q->syntax['.'] = '.';
  q->syntax['\''] = '\'';
}

static void SetupBuiltins(void) {
  memmove(q->str, kSymbols, sizeof(kSymbols));
}

static inline int Car(int x) {
  return q->mem[VALUE(x) + 0];
}

static inline int Cdr(int x) {
  return q->mem[VALUE(x) + 1];
}

static int Set(int i, int k, int v) {
  q->mem[VALUE(i) + 0] = k;
  q->mem[VALUE(i) + 1] = v;
  return i;
}

static int Cons(int car, int cdr) {
  int i, cell;
  i = q->index;
  q->mem[i + 0] = car;
  q->mem[i + 1] = cdr;
  q->index = i + 2;
  cell = OBJECT(CONS, i);
  return cell;
}

static char *StpCpy(char *d, char *s) {
  char c;
  do {
    c = *s++;
    *d++ = c;
  } while (c);
  return d;
}

static int Intern(char *s) {
  int j, cx;
  char c, *z, *t;
  z = q->str;
  c = *z++;
  while (c) {
    for (j = 0;; ++j) {
      if (c != s[j]) {
        break;
      }
      if (!c) {
        return OBJECT(ATOM, z - q->str - j - 1);
      }
      c = *z++;
    }
    while (c) c = *z++;
    c = *z++;
  }
  --z;
  StpCpy(z, s);
  return OBJECT(ATOM, z - q->str);
}

static void PrintChar(unsigned char b) {
  if (write(1, &b, 1) == -1) exit(1);
}

static void PrintString(char *s) {
  char c;
  for (;;) {
    if (!(c = s[0])) break;
    PrintChar(c);
    ++s;
  }
}

static int GetChar(void) {
  unsigned char b;
  static char *l, *p;
  if (l || (l = p = bestlineWithHistory("* ", "sectorlisp"))) {
    if (*p) {
      b = *p++;
    } else {
      free(l);
      l = p = 0;
      b = '\n';
    }
    return b;
  } else {
    PrintChar('\n');
    exit(0);
  }
}

static void GetToken(void) {
  char *t;
  int b, x;
  b = q->look;
  t = q->token;
  for (;;) {
    x = q->syntax[b];
    if (x != ' ') break;
    b = GetChar();
  }
  if (x) {
    *t++ = b;
    b = GetChar();
  } else {
    while (b && !x) {
      *t++ = b;
      b = GetChar();
      x = q->syntax[b];
    }
  }
  *t++ = 0;
  q->look = b;
}

static int ConsumeObject(void) {
  GetToken();
  return GetObject();
}

static int Cadr(int x) {
  return Car(Cdr(x));  /* ((A B C D) (E F G) H I) → (E F G) */
}

static int List(int x, int y) {
  return Cons(x, Cons(y, NIL));
}

static int Quote(int x) {
  return List(ATOM_QUOTE, x);
}

static int GetQuote(void) {
  return Quote(ConsumeObject());
}

static int AddList(int x) {
  return Cons(x, GetList());
}

static int GetList(void) {
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

static int GetObject(void) {
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

static int ReadObject(void) {
  q->look = GetChar();
  GetToken();
  return GetObject();
}

static int Read(void) {
  return ReadObject();
}

static void PrintAtom(int x) {
  PrintString(q->str + VALUE(x));
}

static void PrintList(int x) {
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

static void PrintObject(int x) {
  if (ISATOM(x)) {
    PrintAtom(x);
  } else {
    PrintList(x);
  }
}

static void Print(int i) {
  PrintObject(i);
  PrintString("\r\n");
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § Bootstrap John McCarthy's Metacircular Evaluator    ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

static int Caar(int x) {
  return Car(Car(x));  /* ((A B C D) (E F G) H I) → A */
}

static int Cdar(int x) {
  return Cdr(Car(x));  /* ((A B C D) (E F G) H I) → (B C D) */
}

static int Cadar(int x) {
  return Cadr(Car(x));  /* ((A B C D) (E F G) H I) → B */
}

static int Caddr(int x) {
  return Cadr(Cdr(x));  /* ((A B C D) (E F G) H I) → H */
}

static int Caddar(int x) {
  return Caddr(Car(x));  /* ((A B C D) (E F G) H I) → C */
}

static int Evcon(int c, int a) {
  return Eval(Caar(c), a) != NIL ? Eval(Cadar(c), a) : Evcon(Cdr(c), a);
}

static int Assoc(int x, int a) {
  return a ? Caar(a) == x ? Cdar(a) : Assoc(x, Cdr(a)) : NIL;
}

static int Pairlis(int x, int y, int a) {  /* it's zip() basically */
  int di, si;
  if (!x) return a;
  di = Cons(Car(x), Car(y));
  si = Pairlis(Cdr(x), Cdr(y), a);
  return Cons(di, si); /* Tail-Modulo-Cons */
}

static int Evlis(int m, int a) {
  int di, si;
  if (!m) return NIL;
  di = Eval(Car(m), a);
  si = Evlis(Cdr(m), a);
  return Cons(di, si);
}

static int Apply(int fn, int x, int a) {
  int t1, si, ax;
  if (ISATOM(fn)) {
    switch (fn) {
#if FUNDEF
    case NIL:
      return UNDEFINED;
#endif
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
    t1 = Cdr(fn);
    si = Pairlis(Car(t1), x, a);
    ax = Cadr(t1);
    return Eval(ax, si);
  }
  return UNDEFINED;
}

static int Evaluate(int e, int a) {
  int ax;
  if (ISATOM(e))
    return Assoc(e, a);
  ax = Car(e);
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

static int Eval(int e, int a) {
  int ax;
#if TRACE
  PrintString("> ");
  PrintObject(e);
  PrintString("\r\n  ");
  PrintObject(a);
  PrintString("\r\n");
#endif
  ax = Evaluate(e, a);
#if TRACE
  PrintString("< ");
  PrintObject(ax);
  PrintString("\r\n");
#endif
  return ax;
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § User Interface                                      ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

void Repl(void) {
  for (;;) {
    Print(Eval(Read(), q->globals));
  }
}

int main(int argc, char *argv[]) {
  SetupSyntax();
  SetupBuiltins();
  bestlineSetXlatCallback(bestlineUppercase);
  PrintString("THE LISP CHALLENGE V1\r\n"
              "VISIT GITHUB.COM/JART\r\n");
  Repl();
}
