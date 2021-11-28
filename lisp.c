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
#include <setjmp.h>
#endif

jmp_buf undefined;
int cx, dx, M[0100000];
int Null = sizeof(M) / sizeof(M[0]) / 2;
char *line = "NIL T CAR CDR ATOM COND CONS QUOTE EQ ";
int kT, kEq, kNil, kCar, kCdr, kCond, kAtom, kCons, kQuote;

Get(i) {
  return M[Null + i];
}

Set(i, x) {
  M[Null + i] = x;
}

Read() {
  return ReadObject(ReadAtom(0));
}

Intern(x, y, i) {
  if (x == Get(i) && y == Get(i + 1)) return i;
  if (Get(i)) return Intern(x, y, i + 2);
  Set(i, x);
  Set(i + 1, y);
  return i;
}

ReadAtom(i) {
  int c = ReadChar();
  if (c <= ' ') return ReadAtom(i);
  return Intern(c, c > ')' && dx > ')' ? ReadAtom(0) : 0, i + c * 2);
}

AddList(x) {
  return Cons(x, ReadList());
}

ReadList() {
  int t = ReadAtom(0);
  if (Get(t) == ')') return kNil;
  return AddList(ReadObject(t));
}

ReadObject(t) {
  if (Get(t) != '(') return t;
  return ReadList();
}

PrintAtom(x) {
  do PrintChar(Get(x));
  while ((x = Get(x + 1)));
}

PrintList(x) {
  PrintChar('(');
  if (x < 0) {
    PrintObject(Car(x));
    while ((x = Cdr(x)) != kNil) {
      if (x < 0) {
        PrintChar(' ');
        PrintObject(Car(x));
      } else {
        PrintChar(L'∙');
        PrintObject(x);
        break;
      }
    }
  }
  PrintChar(')');
}

PrintObject(x) {
  if (1./x < 0) {
    PrintList(x);
  } else {
    PrintAtom(x);
  }
}

Print(e) {
  PrintObject(e);
  PrintChar('\n');
}

Car(x) {
  if (x < 0) {
    return Get(x);
  } else {
    longjmp(undefined, x);
  }
}

Cdr(x) {
  if (x < 0) {
    return Get(x + 1);
  } else {
    longjmp(undefined, x);
  }
}

Cons(car, cdr) {
  Set(--cx, cdr);
  Set(--cx, car);
  return cx;
}

Gc(A, x) {
  int C, B = cx;
  x = Copy(x, A, A - B), C = cx;
  while (C < B) Set(--A, Get(--B));
  cx = A;
  return x;
}

Copy(x, m, k) {
  return x < m ? Cons(Copy(Car(x), m, k), 
                      Copy(Cdr(x), m, k)) + k : x;
}

Evlis(m, a) {
  return m != kNil ? Cons(Eval(Car(m), a),
                          Evlis(Cdr(m), a)) : kNil;
}

Pairlis(x, y, a) {
  return x != kNil ? Cons(Cons(Car(x), Car(y)),
                          Pairlis(Cdr(x), Cdr(y), a)) : a;
}

Assoc(x, y) {
  if (y >= 0) longjmp(undefined, x);
  if (x == Car(Car(y))) return Cdr(Car(y));
  return Assoc(x, Cdr(y));
}

Evcon(c, a) {
  if (Eval(Car(Car(c)), a) != kNil) {
    return Eval(Car(Cdr(Car(c))), a);
  } else if (Cdr(c) != kNil) {
    return Evcon(Cdr(c), a);
  } else {
    longjmp(undefined, c);
  }
}

Apply(f, x, a) {
  if (f < 0)      return Eval(Car(Cdr(Cdr(f))), Pairlis(Car(Cdr(f)), x, a));
  if (f == kEq)   return Car(x) == Car(Cdr(x)) ? kT : kNil;
  if (f == kCons) return Cons(Car(x), Car(Cdr(x)));
  if (f == kAtom) return Car(x) < 0 ? kNil : kT;
  if (f == kCar)  return Car(Car(x));
  if (f == kCdr)  return Cdr(Car(x));
  return Apply(Assoc(f, a), x, a);
}

Eval(e, a) {
  int A = cx;
  if (e == kNil) return kNil;
  if (e >= 0) return Assoc(e, a);
  if (Car(e) == kQuote) return Car(Cdr(e));
  if (Car(e) == kCond) {
    e = Evcon(Cdr(e), a);
  } else {
    e = Apply(Car(e), Evlis(Cdr(e), a), a);
  }
  return Gc(A, e);
}

main() {
  int x, a;
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  kNil = ReadAtom(0);
  kT = ReadAtom(0);
  kCar = ReadAtom(0);
  kCdr = ReadAtom(0);
  kAtom = ReadAtom(0);
  kCond = ReadAtom(0);
  kCons = ReadAtom(0);
  kQuote = ReadAtom(0);
  kEq = ReadAtom(0);
  for (a = kNil;;) {
    if (!(x = setjmp(undefined))) {
      x = Read();
      x = Eval(x, a);
      if (x < 0) {
        a = Cons(x, a);
      }
    } else {
      PrintChar('?');
    }
    Print(x);
  }
}

PrintChar(b) {
  fputwc(b, stdout);
}

ReadChar() {
  int b, c, t;
  static char *freeme;
  if (line || (line = freeme = bestlineWithHistory("* ", "sectorlisp"))) {
    if (*line) {
      c = *line++ & 0377;
      if (c >= 0300) {
        for (b = 0200; c & b; b >>= 1) c ^= b;
        while ((*line & 0300) == 0200) {
          c <<= 6;
          c |= *line++ & 0177;
        }
      }
    } else {
      free(freeme);
      freeme = 0;
      line = 0;
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
