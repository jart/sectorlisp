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
#include <stdio.h>
#include <locale.h>
#include <setjmp.h>
#endif

#define var int
#define function
#define Null 0100000

var M[Null * 2];
jmp_buf undefined;

var cx, dx, kT, kEq, kCar, kCdr, kCond, kAtom, kCons, kQuote;

function Set(i, x) {
  M[Null + i] = x;
}

function Get(i) {
  return M[Null + i];
}

function Hash(h, c) {
  return h + c * 2;
}

function Intern(x, y, i) {
  i &= Null - 1;
  if (x == Get(i) && y == Get(i + 1)) return i;
  if (Get(i)) return Intern(x, y, i + 2);
  Set(i, x);
  Set(i + 1, y);
  return i;
}

function ReadAtom(h) {
  var c = ReadChar();
  if (c <= 32) return ReadAtom(h);
  return Intern(c, c > 41 && dx > 41 ?
                ReadAtom(Hash(h, c)) : 0,
                Hash(h, c) - Hash(0, 78));
}

function PrintAtom(x) {
  do PrintChar(Get(x));
  while ((x = Get(x + 1)));
}

function AddList(x) {
  return Cons(x, ReadList());
}

function ReadList() {
  var t = ReadAtom(0);
  if (Get(t) == 41) return 0;
  return AddList(ReadObject(t));
}

function ReadObject(t) {
  if (Get(t) != 40) return t;
  return ReadList();
}

function PrintList(x) {
  PrintChar(40);
  if (x < 0) {
    PrintObject(Car(x));
    while ((x = Cdr(x))) {
      if (x < 0) {
        PrintChar(32);
        PrintObject(Car(x));
      } else {
        PrintChar(8729);
        PrintObject(x);
        break;
      }
    }
  }
  PrintChar(41);
}

function PrintObject(x) {
  if (1./x < 0) {
    PrintList(x);
  } else {
    PrintAtom(x);
  }
}

function Print(e) {
  PrintObject(e);
  PrintChar(10);
}

function Read() {
  return ReadObject(ReadAtom(0));
}

function Car(x) {
  if (x < 0) {
    return Get(x);
  } else {
    Throw(x);
  }
}

function Cdr(x) {
  if (x < 0) {
    return Get(x + 1);
  } else {
    Throw(x);
  }
}

function Cons(car, cdr) {
  Set(--cx, cdr);
  Set(--cx, car);
  return cx;
}

function Gc(A, x) {
  var C, B = cx;
  x = Copy(x, A, A - B), C = cx;
  while (C < B) Set(--A, Get(--B));
  cx = A;
  return x;
}

function Copy(x, m, k) {
  return x < m ? Cons(Copy(Car(x), m, k),
                      Copy(Cdr(x), m, k)) + k : x;
}

function Evlis(m, a) {
  return m ? Cons(Eval(Car(m), a),
                  Evlis(Cdr(m), a)) : 0;
}

function Pairlis(x, y, a) {
  return x ? Cons(Cons(Car(x), Car(y)),
                  Pairlis(Cdr(x), Cdr(y), a)) : a;
}

function Assoc(x, y) {
  if (y >= 0) Throw(x);
  if (x == Car(Car(y))) return Cdr(Car(y));
  return Assoc(x, Cdr(y));
}

function Evcon(c, a) {
  if (Eval(Car(Car(c)), a)) {
    return Eval(Car(Cdr(Car(c))), a);
  } else if (Cdr(c)) {
    return Evcon(Cdr(c), a);
  } else {
    Throw(c);
  }
}

function Apply(f, x, a) {
  if (f < 0)      return Eval(Car(Cdr(Cdr(f))), Pairlis(Car(Cdr(f)), x, a));
  if (f == kEq)   return Car(x) == Car(Cdr(x)) ? kT : 0;
  if (f == kCons) return Cons(Car(x), Car(Cdr(x)));
  if (f == kAtom) return Car(x) < 0 ? 0 : kT;
  if (f == kCar)  return Car(Car(x));
  if (f == kCdr)  return Cdr(Car(x));
  return Apply(Assoc(f, a), x, a);
}

function Eval(e, a) {
  var A = cx;
  if (!e) return 0;
  if (e > 0) return Assoc(e, a);
  if (Car(e) == kQuote) return Car(Cdr(e));
  if (Car(e) == kCond) {
    e = Evcon(Cdr(e), a);
  } else {
    e = Apply(Car(e), Evlis(Cdr(e), a), a);
  }
  return Gc(A, e);
}

function Lisp() {
  var x, a;
  ReadAtom(0);
  kT = ReadAtom(0);
  kCar = ReadAtom(0);
  kCdr = ReadAtom(0);
  kAtom = ReadAtom(0);
  kCond = ReadAtom(0);
  kCons = ReadAtom(0);
  kQuote = ReadAtom(0);
  kEq = ReadAtom(0);
  for (a = 0;;) {
    if (!(x = setjmp(undefined))) {
      x = Read();
      x = Eval(x, a);
      if (x < 0) {
        a = Cons(x, a);
      }
    } else {
      PrintChar(63);
    }
    Print(x);
  }
}

Throw(x) {
  longjmp(undefined, x);
}

PrintChar(b) {
  fputwc(b, stdout);
}

ReadChar() {
  int b, c, t;
  static char *freeme;
  static char *line = "NIL T CAR CDR ATOM COND CONS QUOTE EQ ";
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
      c = 10;
    }
    t = dx;
    dx = c;
    return t;
  } else {
    PrintChar(10);
    exit(0);
  }
}

main() {
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  Lisp();
}
