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

#define ATOM 1
#define CONS 0

#define ISATOM(x)   ((x)&1)
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

const char kSymbols[] =
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

int g_look;
int g_index;
char g_token[128];
int g_mem[8192];
char g_str[8192];

int GetList(void);
int GetObject(void);
void PrintObject(int);
int Eval(int, int);

void SetupBuiltins(void) {
  memmove(g_str, kSymbols, sizeof(kSymbols));
}

int Car(int x) {
  return g_mem[VALUE(x) + 0];
}

int Cdr(int x) {
  return g_mem[VALUE(x) + 1];
}

int Cons(int car, int cdr) {
  int i, cell;
  i = g_index;
  g_mem[i + 0] = car;
  g_mem[i + 1] = cdr;
  g_index = i + 2;
  cell = OBJECT(CONS, i);
  return cell;
}

char *StpCpy(char *d, char *s) {
  char c;
  do {
    c = *s++;
    *d++ = c;
  } while (c);
  return d;
}

int Intern(char *s) {
  int j, cx;
  char c, *z, *t;
  z = g_str;
  c = *z++;
  while (c) {
    for (j = 0;; ++j) {
      if (c != s[j]) {
        break;
      }
      if (!c) {
        return OBJECT(ATOM, z - g_str - j - 1);
      }
      c = *z++;
    }
    while (c) c = *z++;
    c = *z++;
  }
  --z;
  StpCpy(z, s);
  return OBJECT(ATOM, z - g_str);
}

void PrintChar(unsigned char b) {
  if (write(1, &b, 1) == -1) exit(1);
}

void PrintString(const char *s) {
  char c;
  for (;;) {
    if (!(c = s[0])) break;
    PrintChar(c);
    ++s;
  }
}

int GetChar(void) {
  int b;
  static char *l, *p;
  if (l || (l = p = bestlineWithHistory("* ", "sectorlisp"))) {
    if (*p) {
      b = *p++ & 255;
    } else {
      free(l);
      l = p = 0;
      b = '\n';
    }
    return b;
  } else {
    PrintString("\n");
    exit(0);
  }
}

void GetToken(void) {
  int al;
  char *di;
  di = g_token;
  do {
    if (g_look > ' ') {
      *di++ = g_look;
    }
    al = g_look;
    g_look = GetChar();
  } while (al <= ' ' || (al > ')' && g_look > ')'));
  *di++ = 0;
}

int ConsumeObject(void) {
  GetToken();
  return GetObject();
}

int List(int x, int y) {
  return Cons(x, Cons(y, NIL));
}

int Quote(int x) {
  return List(ATOM_QUOTE, x);
}

int GetQuote(void) {
  return Quote(ConsumeObject());
}

int AddList(int x) {
  return Cons(x, GetList());
}

int GetList(void) {
  GetToken();
#if QUOTES
  if (*g_token == '\'') return AddList(GetQuote());
#endif
  if (*g_token == ')') return NIL;
  return AddList(GetObject());
}

int GetObject(void) {
#if QUOTES
  if (*g_token == '\'') return GetQuote();
#endif
  if (*g_token == '(') return GetList();
  return Intern(g_token);
}

int ReadObject(void) {
  g_look = GetChar();
  GetToken();
  return GetObject();
}

int Read(void) {
  return ReadObject();
}

void PrintAtom(int x) {
  PrintString(g_str + VALUE(x));
}

void PrintList(int x) {
#if QUOTES
  if (Car(x) == ATOM_QUOTE) {
    PrintChar('\'');
    PrintObject(Car(Cdr(x)));
    return;
  }
#endif
  PrintChar('(');
  PrintObject(Car(x));
  while ((x = Cdr(x)) != NIL) {
    if (!ISATOM(x)) {
      PrintChar(' ');
      PrintObject(Car(x));
    } else {
      PrintString("∙");
      PrintObject(x);
      break;
    }
  }
  PrintChar(')');
}

void PrintObject(int x) {
  if (ISATOM(x)) {
    PrintAtom(x);
  } else {
    PrintList(x);
  }
}

void Print(int i) {
  PrintObject(i);
  PrintString("\n");
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § Bootstrap John McCarthy's Metacircular Evaluator    ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

int Assoc(int x, int y) {
  if (y == NIL) return NIL;
  if (x == Car(Car(y))) return Cdr(Car(y));
  return Assoc(x, Cdr(y));
}

int Evcon(int c, int a) {
  if (Eval(Car(Car(c)), a) != NIL) {
    return Eval(Car(Cdr(Car(c))), a);
  } else {
    return Evcon(Cdr(c), a);
  }
}

int Pairlis(int x, int y, int a) {
  int di, si; /* it's zip() basically */
  if (x == NIL) return a;
  di = Cons(Car(x), Car(y));
  si = Pairlis(Cdr(x), Cdr(y), a);
  return Cons(di, si); /* Tail-Modulo-Cons */
}

int Evlis(int m, int a) {
  int di, si;
  if (m == NIL) return NIL;
  di = Eval(Car(m), a);
  si = Evlis(Cdr(m), a);
  return Cons(di, si);
}

int Apply(int fn, int x, int a) {
  int t1, si, ax;
  if (ISATOM(fn)) {
    switch (fn) {
#if FUNDEF
    case NIL:
      return UNDEFINED;
#endif
    case ATOM_CAR:
      return Car(Car(x));
    case ATOM_CDR:
      return Cdr(Car(x));
    case ATOM_ATOM:
      return ISATOM(Car(x)) ? ATOM_T : NIL;
    case ATOM_CONS:
      return Cons(Car(x), Car(Cdr(x)));
    case ATOM_EQ:
      return Car(x) == Car(Cdr(x)) ? ATOM_T : NIL;
    default:
      return Apply(Eval(fn, a), x, a);
    }
  }
  if (Car(fn) == ATOM_LAMBDA) {
    t1 = Cdr(fn);
    si = Pairlis(Car(t1), x, a);
    ax = Car(Cdr(t1));
    return Eval(ax, si);
  }
  return UNDEFINED;
}

int Evaluate(int e, int a) {
  int ax;
  if (ISATOM(e))
    return Assoc(e, a);
  ax = Car(e);
  if (ISATOM(ax)) {
    if (ax == ATOM_QUOTE)
      return Car(Cdr(e));
    if (ax == ATOM_COND)
      return Evcon(Cdr(e), a);
  }
  return Apply(ax, Evlis(Cdr(e), a), a);
}

int Eval(int e, int a) {
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
    Print(Eval(Read(), NIL));
  }
}

int main(int argc, char *argv[]) {
  SetupBuiltins();
  bestlineSetXlatCallback(bestlineUppercase);
  PrintString("THE LISP CHALLENGE V1\r\n"
              "VISIT GITHUB.COM/JART\r\n");
  Repl();
}
