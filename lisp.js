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
var (*funcall)();
jmp_buf undefined;
//`

var cx, dx, depth, panic;
var cHeap, cGets, cSets, cPrints;
var kT, kEq, kCar, kCdr, kCond, kAtom, kCons, kQuote, kDefine;

function Get(i) {
  ++cGets;
  return M[Null + i];
}

function Set(i, x) {
  ++cSets;
  M[Null + i] = x;
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
  if (cx < cHeap) cHeap = cx;
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

function Read() {
  return ReadObject(ReadAtom(0));
}

function PrintAtom(x) {
  do PrintChar(Get(x));
  while ((x = Get(x + 1)));
}

function PrintList(x) {
  PrintChar(Ord('('));
  if (x < 0) {
    Print(Car(x));
    while ((x = Cdr(x))) {
      if (panic && cPrints > panic) {
        PrintChar(Ord(' '));
        PrintChar(0x2026);
        break;
      }
      if (x < 0) {
        PrintChar(Ord(' '));
        Print(Car(x));
      } else {
        PrintChar(Ord(' '));
        PrintChar(Ord('.'));
        PrintChar(Ord(' '));
        Print(x);
        break;
      }
    }
  }
  PrintChar(Ord(')'));
}

function Print(x) {
  ++cPrints;
  if (1./x < 0) {
    PrintList(x);
  } else {
    PrintAtom(x);
  }
}

function List(x, y) {
  return Cons(x, Cons(y, 0));
}

function Define(A, x, a) {
  return Gc(A, Cons(x, Remove(Car(x), a)));
}

function Remove(x, y) {
  if (!y) return y;
  if (x == Car(Car(y))) return Cdr(y);
  return Cons(Car(y), Remove(x, Cdr(y)));
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
    Throw(Cons(kCond, c));
  }
}

function Apply(f, x, a) {
  if (f < 0)      return Eval(Car(Cdr(Cdr(f))), Pairlis(Car(Cdr(f)), x, a));
  if (f == kEq)   return Car(x) == Car(Cdr(x)) ? kT : 0;
  if (f == kCons) return Cons(Car(x), Car(Cdr(x)));
  if (f == kAtom) return Car(x) < 0 ? 0 : kT;
  if (f == kCar)  return Car(Car(x));
  if (f == kCdr)  return Cdr(Car(x));
  return funcall(f, Assoc(f, a), x, a);
}

function Eval(e, a) {
  if (!e) return e;
  if (e > 0) return Assoc(e, a);
  if (Car(e) == kQuote) return Car(Cdr(e));
  if (Car(e) == kCond) return Evcon(Cdr(e), a);
  return Apply(Car(e), Evlis(Cdr(e), a), a);
}

function Funcall(f, l, x, a) {
  var A = cx;
  return Gc(A, Apply(l, x, a));
}

function Funtrace(f, l, x, a) {
  var y, i, A = cx;
  Indent(depth);
  Print(f);
  Print(x);
  PrintChar(Ord('\n'));
  depth += 2;
  y = Funcall(f, l, x, a);
  depth -= 2;
  Indent(depth);
  Print(f);
  Print(x);
  PrintChar(Ord(' '));
  PrintChar(0x2192);
  PrintChar(Ord(' '));
  Print(y);
  PrintChar(Ord('\n'));
  return y;
}

function Indent(i) {
  if (i) {
    PrintChar(Ord(' '));
    Indent(i - 1);
  }
}

function Dump(a) {
  if (a) {
    Dump(Cdr(a));
    PrintChar(Ord('('));
    Print(kDefine);
    PrintChar(Ord(' '));
    Print(Car(Car(a)));
    PrintChar(Ord(' '));
    PrintChar(Ord('.'));
    PrintChar(Ord(' '));
    Print(Cdr(Car(a)));
    PrintChar(Ord(')'));
    PrintChar(Ord('\n'));
  }
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

main(argc, argv)
  char *argv[];
{
  var x, a, A;
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 't') {
    funcall = Funtrace;
  } else {
    funcall = Funcall;
  }
  LoadBuiltins();
  for (a = 0;;) {
    A = cx;
    if (!(x = setjmp(undefined))) {
      x = Read();
      if (x < 0 && Car(x) == kDefine) {
        a = Define(0, Cdr(x), a);
        SaveMachine(a);
        continue;
      }
      x = Eval(x, a);
    } else {
      x = ~x;
      PrintChar('?');
    }
    Print(x);
    PrintChar('\n');
    Gc(A, 0);
  }
}

#if 0
//`
////////////////////////////////////////////////////////////////////////////////
// JavaScript Specific Code for https://justine.lol/

var a, code, index, output, funcall, M, Null;
var eInput, eOutput, eEval, eReset, eLoad, eTrace, ePrograms;

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
  cHeap = 0;
  cGets = 0;
  cSets = 0;
  cPrints = 0;
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

function GetMillis() {
  if (typeof performance != "undefined") {
    return performance.now();
  } else {
    return 0;
  }
}

function Lisp() {
  var x, A, d, t;
  d = 0;
  cGets = 0;
  cSets = 0;
  cHeap = cx;
  cPrints = 0;
  output = "";
  while (dx) {
    if (dx <= Ord(' ')) {
      ReadChar();
    } else {
      A = cx;
      try {
        x = Read();
        if (x < 0 && Car(x) == kDefine) {
          a = Define(0, Cdr(x), a);
          continue;
        }
        t = GetMillis();
        x = Eval(x, a);
        d += GetMillis() - t;
      } catch (z) {
        PrintChar(Ord('?'));
        x = z;
      }
      Print(x);
      PrintChar(Ord('\n'));
      Gc(A, 0);
    }
  }
  eOutput.innerText = output;
  SaveMachine(a);
  SaveOutput();
  ReportUsage(d);
}

function Load(s) {
  code = s + "\n";
  dx = Ord(s);
  index = 1;
}

function OnEval() {
  Load(eInput.value.toUpperCase());
  Lisp();
}

function OnReset() {
  var t;
  output = "";
  t = GetMillis();
  try {
    Dump(a);
    eOutput.innerText = output;
    Reset();
  } catch (e) {
    /* ignored */
  }
  t = GetMillis() - t;
  localStorage.removeItem("sectorlisp.machine");
  SaveOutput();
  ReportUsage(t);
}

function OnTrace() {
  var t;
  Load(eInput.value);
  t = panic;
  depth = 0;
  panic = 10000;
  funcall = Funtrace;
  Lisp();
  funcall = Funcall;
  panic = t;
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
    cHeap = cx;
  }
}

function SaveOutput() {
  if (typeof localStorage != "undefined") {
    localStorage.setItem("input", document.getElementById("input").value);
    localStorage.setItem("output", eOutput.innerText);
  }
}

function FormatInt(i) {
  return i.toLocaleString();
}

function FormatDuration(d) {
  return d ? Math.round(d * 1000) / 1000 : 0;
}

function ReportUsage(d) {
  var i, c, s;
  for (c = i = 0; i < Null; i += 2) {
    if (M[Null + i]) ++c;
  }
  document.getElementById("ops").innerText =
      FormatInt(cGets) + " gets / " +
      FormatInt(cSets) + " sets / " +
      FormatDuration(d) + " ms";
  document.getElementById("mem").innerText =
      FormatInt((-cx >> 1) + c) + " / " +
      FormatInt((-cHeap >> 1) + c) + " / " +
      FormatInt(Null) + " doublewords";
}

function Discount(f) {
  return function() {
    var x, g, h, s;
    g = cGets;
    s = cSets;
    h = cHeap;
    x = f.apply(this, arguments);
    cHeap = h;
    cSets = s;
    cGets = g;
    return x;
  };
}

function SetUp() {
  funcall = Funcall;
  Read = Discount(Read);
  Print = Discount(Print);
  Define = Discount(Define);
  eLoad = document.getElementById("load");
  eInput = document.getElementById("input");
  eReset = document.getElementById("reset");
  eTrace = document.getElementById("trace");
  eOutput = document.getElementById("output");
  eEval = document.getElementById("eval");
  ePrograms = document.getElementById("programs");
  window.onclick = OnWindowClick;
  eLoad.onclick = OnLoad;
  eReset.onclick = OnReset;
  eTrace.onclick = OnTrace;
  eEval.onclick = OnEval;
  Reset();
  RestoreMachine();
  ReportUsage();
}

SetUp();

// `
#endif
//`
