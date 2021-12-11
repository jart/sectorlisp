/*bin/echo '#-*- indent-tabs-mode:nil;js-indent-level:2;coding:utf-8 -*-

  SectorLISP v2.o (ISC License)
  Copyright 2021 Justine Tunney

  This file implements SectorLISP as a C / JavaScript polyglot and
  includes friendly branch features such as the undefined behavior
  exceptions handlers, optimized interning, and global definitions

(aset standard-display-table #x2029 [?¶]) ;; emacs protip '>/dev/null
curl -so bestline.c -z bestline.c https://justine.lol/sectorlisp2/bestline.c
curl -so bestline.h -z bestline.h https://justine.lol/sectorlisp2/bestline.h
[ lisp.js -nt lisp ] && cc -w -xc lisp.js bestline.c -o lisp
exec ./lisp "$@"
exit
*/

// `
#include "bestline.h"
#ifndef __COSMOPOLITAN__
#include <stdio.h>
#include <locale.h>
#include <setjmp.h>
#endif
#define var int
#define function
#define Null 16384
var M[Null * 2];
jmp_buf undefined;
//`

var cx, dx, lo, kT, kEq, kCar, kCdr, kCond, kAtom, kCons, kQuote, kDefine;

function Set(i, x) {
  M[Null + i] = x;
}

function Get(i) {
  return M[Null + i];
}

function Car(x) {
  if (x > 0) Throw(List(kCar, x));
  return x ? Get(x) : +0;
}

function Cdr(x) {
  if (x > 0) Throw(List(kCdr, x));
  return x ? Get(x + 1) : -0;
}

function Cons(car, cdr) {
  Set(--cx, cdr);
  Set(--cx, car);
  if (cx < lo) lo = cx;
  return cx;
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
  if (c <= Ord(' ')) return ReadAtom(h);
  return Intern(c, c > Ord(')') && dx > Ord(')') ?
                ReadAtom(Hash(h, c)) : 0,
                Hash(h, c) - Hash(0, Ord('N')));
}

function PrintAtom(x) {
  do PrintChar(Get(x));
  while ((x = Get(x + 1)));
}

function ReadList() {
  var x;
  if ((x = Read()) > 0) {
    if (Get(x) == Ord(')')) return -0;
    if (Get(x) == Ord('.') && !Get(x + 1)) {
      x = Read();
      ReadList();
      return x;
    }
  }
  return Cons(x, ReadList());
}

function ReadObject(t) {
  if (Get(t) != Ord('(')) return t;
  return ReadList();
}

function PrintList(x) {
  PrintChar(Ord('('));
  if (x < 0) {
    PrintObject(Car(x));
    while ((x = Cdr(x))) {
      if (x < 0) {
        PrintChar(Ord(' '));
        PrintObject(Car(x));
      } else {
        PrintChar(0x2219);
        PrintObject(x);
        break;
      }
    }
  }
  PrintChar(Ord(')'));
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
  PrintChar(Ord('\n'));
}

function Read() {
  return ReadObject(ReadAtom(0));
}

function Remove(x, y) {
  if (!y) return y;
  if (x == Car(Car(y))) return Cdr(y);
  return Cons(Car(y), Remove(x, Cdr(y)));
}

function List(x, y) {
  return Cons(x, Cons(y, 0));
}

function Define(x, y) {
  return Cons(Cons(x, Read()), Remove(x, y));
}

function Gc(A, x) {
  var C, B = cx;
  x = Copy(x, A, A - B), C = cx;
  while (C < B) Set(--A, Get(--B));
  return cx = A, x;
}

function Copy(x, m, k) {
  return x < m ? Cons(Copy(Car(x), m, k),
                      Copy(Cdr(x), m, k)) + k : x;
}

function Evlis(m, a) {
  return m ? Cons(Eval(Car(m), a),
                  Evlis(Cdr(m), a)) : m;
}

function Pairlis(x, y, a) {
  if (!!x ^ !!y) Throw(List(x, y));
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
  if (!e) return e;
  if (e > 0) return Assoc(e, a);
  if (Car(e) == kQuote) return Car(Cdr(e));
  if (Car(e) == kCond) return Gc(A, Evcon(Cdr(e), a));
  return Gc(A, Apply(Car(e), Evlis(Cdr(e), a), a));
}

function LoadBuiltins() {
  ReadAtom(0);
  kT = ReadAtom(0);
  kEq = ReadAtom(0);
  kCar = ReadAtom(0);
  kCdr = ReadAtom(0);
  kAtom = ReadAtom(0);
  kCond = ReadAtom(0);
  kCons = ReadAtom(0);
  kQuote = ReadAtom(0);
  kDefine = ReadAtom(0);
}

// `
////////////////////////////////////////////////////////////////////////////////
// ANSI POSIX C Specific Code

Ord(c) {
  return c;
}

Throw(x) {
  longjmp(undefined, ~x);
}

PrintChar(b) {
  fputwc(b, stdout);
}

SaveMachine(a) {
}

ReadChar() {
  int b, c, t;
  static char *freeme;
  static char *line = "NIL T EQ CAR CDR ATOM COND CONS QUOTE DEFINE ";
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
    exit(0);
  }
}

main() {
  var x, a, A;
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  LoadBuiltins();
  for (a = 0;;) {
    A = cx;
    if (!(x = setjmp(undefined))) {
      x = Read();
      if (x == kDefine) {
        a = Gc(0, Define(Read(), a));
        SaveMachine(a);
        continue;
      }
      x = Eval(x, a);
    } else {
      x = ~x;
      PrintChar('?');
    }
    Print(x);
    Gc(A, 0);
  }
}

#if 0
//`
////////////////////////////////////////////////////////////////////////////////
// JavaScript Specific Code for https://justine.lol/

var a, code, index, output, M, Null;
var eInput, eOutput, eSubmit, eReset, eLoad, ePrograms;

function Throw(x) {
  throw x;
}

function Ord(s) {
  return s.charCodeAt(0);
}

function Reset() {
  var i;
  a = 0;
  cx = 0;
  lo = 0;
  Null = 16384;
  M = new Array(Null * 2);
  for (i = 0; i < M.length; ++i) {
    M[i] = 0; /* make json smaller */
  }
  Load("NIL T EQ CAR CDR ATOM COND CONS QUOTE DEFINE ");
  LoadBuiltins()
}

function PrintChar(c) {
  output += String.fromCharCode(c);
}

function ReadChar() {
  var ax;
  if (code.length) {
    ax = dx;
    if (index < code.length) {
      dx = code.charCodeAt(index++);
    } else {
      code = "";
      dx = 0;
    }
    return ax;
  } else {
    Throw(0);
  }
}

function Lisp() {
  var x, A;
  lo = cx;
  output = '';
  while (dx) {
    if (dx <= Ord(' ')) {
      ReadChar();
    } else {
      A = cx;
      try {
        x = Read();
        if (x == kDefine) {
          a = Gc(0, Define(Read(), a));
          continue;
        }
        x = Eval(x, a);
      } catch (z) {
        PrintChar(Ord('?'));
        x = z;
      }
      Print(x);
      Gc(A, 0);
    }
  }
  eOutput.innerText = output;
  SaveMachine(a);
  SaveOutput();
  ReportUsage();
}

function Load(s) {
  code = s + "\n";
  dx = Ord(s);
  index = 1;
}

function OnSubmit() {
  Load(eInput.value.toUpperCase());
  Lisp();
}

function Dump(a) {
  if (!a) return;
  Dump(Cdr(a));
  output += "DEFINE ";
  PrintObject(Car(Car(a)));
  output += " ";
  PrintObject(Cdr(Car(a)));
  output += "\n";
}

function OnReset() {
  output = "";
  try {
    Dump(a);
    eOutput.innerText = output;
    Reset();
  } catch (e) {
    /* ignored */
  }
  localStorage.removeItem("sectorlisp.machine");
  SaveOutput();
  ReportUsage();
}

function OnLoad() {
  ePrograms.classList.toggle("show");
}

function OnWindowClick(event) {
  if (!event.target.matches("#load")) {
    ePrograms.classList.remove("show");
  }
}

function SaveMachine(a) {
  var machine;
  if (typeof localStorage != "undefined") {
    machine = [M, a, cx];
    localStorage.setItem("sectorlisp.machine", JSON.stringify(machine));
  }
}

function RestoreMachine() {
  var machine;
  if (typeof localStorage != "undefined" &&
      (machine = JSON.parse(localStorage.getItem("sectorlisp.machine")))) {
    M = machine[0];
    a = machine[1];
    cx = machine[2];
    lo = cx;
  }
}

function SaveOutput() {
  if (typeof localStorage != "undefined") {
    localStorage.setItem("input", document.getElementById("input").value);
    localStorage.setItem("output", eOutput.innerText);
  }
}

function Number(i) {
  return i.toLocaleString();
}

function ReportUsage() {
  var i, c;
  for (c = i = 0; i < Null; i += 2) {
    if (Get(i)) ++c;
  }
  document.getElementById("usage").innerText =
      Number((-cx >> 1) + c) + " / " +
      Number((-lo >> 1) + c) + " / " +
      Number(Null) + " doublewords";
}

function SetUp() {
  eLoad = document.getElementById("load");
  eInput = document.getElementById("input");
  eReset = document.getElementById("reset");
  eOutput = document.getElementById("output");
  eSubmit = document.getElementById("submit");
  ePrograms = document.getElementById("programs");
  window.onclick = OnWindowClick;
  eSubmit.onclick = OnSubmit;
  eReset.onclick = OnReset;
  eLoad.onclick = OnLoad;
  Reset();
  RestoreMachine();
  ReportUsage();
}

SetUp();

// `
#endif
//`
