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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <limits.h>
#endif

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § LISP Machine                                        ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

#define kT          4
#define kQuote      6
#define kCond       12
#define kAtom       17
#define kCar        22
#define kCdr        26
#define kCons       30
#define kEq         35

#define M (RAM + sizeof(RAM) / sizeof(RAM[0]) / 2)
#define S "NIL\0T\0QUOTE\0COND\0ATOM\0CAR\0CDR\0CONS\0EQ"

int cx; /* stores negative memory use */
int dx; /* stores lookahead character */
int RAM[0100000]; /* your own ibm7090 */

Intern() {
  int i, j, x;
  for (i = 0; (x = M[i++]);) {
    for (j = 0;; ++j) {
      if (x != RAM[j]) break;
      if (!x) return i - j - 1;
      x = M[i++];
    }
    while (x)
      x = M[i++];
  }
  j = 0;
  x = --i;
  while ((M[i++] = RAM[j++]));
  return x;
}

GetChar() {
  int c, t;
  static char *l, *p;
  if (l || (l = p = bestlineWithHistory("* ", "sectorlisp"))) {
    if (*p) {
      c = *p++ & 255;
    } else {
      free(l);
      l = p = 0;
      c = '\n';
    }
    t = dx;
    dx = c;
    return t;
  } else {
    PrintChar('\n');
    exit(0);
  }
}

PrintChar(b) {
  fputwc(b, stdout);
}

GetToken() {
  int c, i = 0;
  do if ((c = GetChar()) > ' ') RAM[i++] = c;
  while (c <= ' ' || (c > ')' && dx > ')'));
  RAM[i] = 0;
  return c;
}

AddList(x) {
  return Cons(x, GetList());
}

GetList() {
  int c = GetToken();
  if (c == ')') return 0;
  return AddList(GetObject(c));
}

GetObject(c) {
  if (c == '(') return GetList();
  return Intern();
}

Read() {
  return GetObject(GetToken());
}

PrintAtom(x) {
  int c;
  for (;;) {
    if (!(c = M[x++])) break;
    PrintChar(c);
  }
}

PrintList(x) {
  PrintChar('(');
  PrintObject(Car(x));
  while ((x = Cdr(x))) {
    if (x < 0) {
      PrintChar(' ');
      PrintObject(Car(x));
    } else {
      PrintChar(L'∙');
      PrintObject(x);
      break;
    }
  }
  PrintChar(')');
}

PrintObject(x) {
  if (x < 0) {
    PrintList(x);
  } else {
    PrintAtom(x);
  }
}

Print(e) {
  PrintObject(e);
  PrintChar('\n');
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § Bootstrap John McCarthy's Metacircular Evaluator    ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

Car(x) {
  return M[x];
}

Cdr(x) {
  return M[x + 1];
}

Cons(car, cdr) {
  M[--cx] = cdr;
  M[--cx] = car;
  return cx;
}

Gc(x, m, k) {
  return x < m ? Cons(Gc(Car(x), m, k), 
                      Gc(Cdr(x), m, k)) + k : x;
}

Evlis(m, a) {
  return m ? Cons(Eval(Car(m), a),
                  Evlis(Cdr(m), a)) : 0;
}

Pairlis(x, y, a) {
  return x ? Cons(Cons(Car(x), Car(y)),
                  Pairlis(Cdr(x), Cdr(y), a)) : a;
}

Assoc(x, y) {
  if (!y) return 0;
  if (x == Car(Car(y))) return Cdr(Car(y));
  return Assoc(x, Cdr(y));
}

Evcon(c, a) {
  if (Eval(Car(Car(c)), a)) {
    return Eval(Car(Cdr(Car(c))), a);
  } else {
    return Evcon(Cdr(c), a);
  }
}

Apply(f, x, a) {
  if (f < 0)      return Eval(Car(Cdr(Cdr(f))), Pairlis(Car(Cdr(f)), x, a));
  if (f > kEq)    return Apply(Eval(f, a), x, a);
  if (f == kEq)   return Car(x) == Car(Cdr(x)) ? kT : 0;
  if (f == kCons) return Cons(Car(x), Car(Cdr(x)));
  if (f == kAtom) return Car(x) < 0 ? 0 : kT;
  if (f == kCar)  return Car(Car(x));
  if (f == kCdr)  return Cdr(Car(x));
}

Eval(e, a) {
  int A, B, C;
  if (e >= 0)
    return Assoc(e, a);
  if (Car(e) == kQuote)
    return Car(Cdr(e));
  A = cx;
  if (Car(e) == kCond) {
    e = Evcon(Cdr(e), a);
  } else {
    e = Apply(Car(e), Evlis(Cdr(e), a), a);
  }
  B = cx;
  e = Gc(e, A, A - B);
  C = cx;
  while (C < B)
    M[--A] = M[--B];
  cx = A;
  return e;
}

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § User Interface                                      ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

main() {
  int i;
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  for(i = 0; i < sizeof(S); ++i) M[i] = S[i];
  for (;;) {
    cx = 0;
    Print(Eval(Read(), 0));
  }
}
