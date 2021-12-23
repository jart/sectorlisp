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
#include <assert.h>
#include <stdio.h>
#include <locale.h>
#include <setjmp.h>
#endif
#define var int
#define function
#define Null 01000000
var M[Null * 2];
var (*funcall)();
jmp_buf undefined;
//`

var ax, cx, dx, depth, panic, fail;
var cHeap, cGets, cSets, cReads, cPrints;
var kEq, kCar, kCdr, kCond, kAtom, kCons, kQuote, kDefine;

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
  if (cx == -Null) Throw(kCons);
  Set(--cx, cdr);
  Set(--cx, car);
  if (cx < cHeap) cHeap = cx;
  return cx;
}

function Probe(h, p) {
  return (h + p * p) & (Null / 2 - 1);
}

function Hash(h, x) {
  return ((h + x) * 60611 + 20485) & (Null / 2 - 1);
}

function Intern(x, y, h, p) {
  if (x == Get(h) && y == Get(h + Null / 2)) return h;
  if (Get(h)) return Intern(x, y, Probe(h, p), p + 1);
  Set(h, x);
  Set(h + Null/2, y);
  return h;
}

function ReadAtom() {
  var x, y;
  ax = y = 0;
  do x = ReadChar();
  while (x <= Ord(' '));
  if (x > Ord(')') && dx > Ord(')')) y = ReadAtom();
  return Intern(x, y, (ax = Hash(x, ax)), 1);
}

function ReadList() {
  var x, y;
  if ((x = Read()) > 0) {
    if (Get(x) == Ord(')')) return -0;
    if (Get(x) == Ord('.') && !Get(x + 1)) {
      x = Read();
      y = ReadList();
      if (!y) {
        return x;
      } else {
        Throw(y);
      }
    }
  }
  return Cons(x, ReadList());
}

function Read() {
  var t;
  ++cReads;
  t = ReadAtom();
  if (Get(t) != Ord('(')) return t;
  return ReadList();
}

function PrintAtom(x) {
  do PrintChar(Get(x));
  while ((x = Get(x + Null / 2)));
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
  return Cons(x, Cons(y, -0));
}

function Evcon(c, a, t) {
  if (c >= 0) Throw(kCond);
  if (Eval(Car(Car(c)), a)) {
    return Apply(Car(Cdr(Car(c))), a, t);
  } else {
    return Evcon(Cdr(c), a, t);
  }
}

function Assoc(x, y) {
  var c, p;
  for (c = 3; y < 0; y = M[Null + y + 1], c += 3) {
    if (x == M[Null + M[Null + y]]) {
      cGets += c;
      return M[Null + M[Null + y] + 1];
    }
  }
  Throw(x);
}

function Bind(x, y, u, a) {
  while (x) {
    a = Cons(Cons(Car(x), Arg1(y, u)), a);
    x = Cdr(x);
    y = Cdr(y);
  }
  return a;
}

function Gc(A, x) {
  var C, B = cx;
  x = Copy(x, A, A - B), C = cx;
  while (C < B) Set(--A, Get(--B));
  return cx = A, x;
}

function Copy(x, m, k) {
  var r, y, z;
  if (x >= m) return x;
  r = (y = Cons(Copy(Car(x), m, k), 0)) + k;
  for (;;) {
    if ((x = Cdr(x)) < m) {
      z = Cons(Copy(Car(x), m, k), 0);
      Set(y + 1, z + k);
      y = z;
    } else {
      Set(y + 1, x);
      break;
    }
  }
  return r;
}

function Evlam(e, a, t, f, x) {
  var b, p, u, A;
  p = Car(Cdr(f));
  b = Car(Cdr(Cdr(f)));
  for (A = cx, u = a;;) {
    u = Bind(p, x, u, a);
    x = funcall(b, u, t, a);
    if (x < 0 && Car(x) == t) {
      x = Gc(A, Cons(u, Cdr(x)));
      u = Car(x);
      x = Cdr(x);
    } else {
      return Gc(A, Eval(x, u));
    }
  }
}

function Apply(e, a, t) {
  if (!e) return e;
  if (e > 0) return t ? e : Assoc(e, a);
  return Evfun(e, a, t, Car(e), Cdr(e));
}

function Evfun(e, a, t, f, x) {
  if (f == kCond) return Evcon(x, a, t);
  if (t) return e;
  if (f == kQuote) return Car(x);
  if (f == kCons) return Cons(Arg1(x, a), Arg2(x, a));
  if (f == kEq) return Arg1(x, a) == Arg2(x, a);
  if (f == kAtom) return Arg1(x, a) >= 0;
  if (f == kCar) return Car(Arg1(x, a));
  if (f == kCdr) return Cdr(Arg1(x, a));
  return Evlam(e, a, f, f > 0 ? Assoc(f, a) : f, x);
}

function Arg1(x, a) {
  return Eval(Car(x), a);
}

function Arg2(x, a) {
  return Arg1(Cdr(x), a);
}

function Eval(e, a) {
  return Apply(e, a, 0);
}

function Trace(b, u, t, a) {
  var i, y;
  if (t > 0) {
    Indent(depth);
    PrintChar(Ord('('));
    Print(t);
    for (i = u; i != a; i = Cdr(i)) {
      PrintChar(Ord(' '));
      Print(Cdr(Car(i)));
    }
    PrintChar(Ord(')'));
    PrintChar(Ord('\r'));
    PrintChar(Ord('\n'));
    depth += 2;
  }
  y = Apply(b, u, t);
  if (t > 0) {
    depth -= 2;
    Indent(depth);
    Print(t);
    PrintChar(Ord(' '));
    PrintChar(0x2192);
    PrintChar(Ord(' '));
    Print(y);
    PrintChar(Ord('\r'));
    PrintChar(Ord('\n'));
  }
  return y;
}

function Indent(i) {
  for (; i; --i) {
    PrintChar(Ord(' '));
  }
}

function DumpAlist(a) {
  PrintChar(Ord('('));
  PrintChar(Ord('\n'));
  for (;a ;a = Cdr(a)) {
    PrintChar(Ord('('));
    Print(Car(Car(a)));
    PrintChar(Ord(' '));
    PrintChar(Ord('.'));
    PrintChar(Ord(' '));
    Print(Cdr(Car(a)));
    PrintChar(Ord(')'));
    PrintChar(Ord('\n'));
  }
  PrintChar(Ord(')'));
}

function DumpDefines(a) {
  if (a) {
    DumpDefines(Cdr(a));
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
  Read();
  Read();
  kEq = Read();
  kCar = Read();
  kCdr = Read();
  kAtom = Read();
  kCond = Read();
  kCons = Read();
  kQuote = Read();
  kDefine = Read();
}

function Crunch(e, B) {
  var x, y, i;
  if (e >= 0) return e;
  x = Crunch(Car(e), B);
  y = Crunch(Cdr(e), B);
  for (i = B - 2; i >= cx; i -= 2) {
    if (x == Car(i) &&
        y == Cdr(i)) {
      return i - B;
    }
  }
  return Cons(x, y) - B;
}

function Compact(x) {
  var C, B = cx, A = 0;
  x = Crunch(x, B), C = cx;
  while (C < B) Set(--A, Get(--B));
  return cx = A, x;
}

function Remove(x, y) {
  if (!y) return y;
  if (x == Car(Car(y))) return Cdr(y);
  return Cons(Car(y), Remove(x, Cdr(y)));
}

function Define(x, a) {
  return Compact(Cons(x, Remove(Car(x), a)));
}

// `
////////////////////////////////////////////////////////////////////////////////
// ANSI POSIX C Specific Code

Ord(c) {
  return c;
}

Throw(x) {
  if (fail < 255) ++fail;
  longjmp(undefined, ~x);
}

PrintChar(b) {
  fputwc(b, stdout);
}

SaveAlist(a) {
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
    exit(fail);
  }
}

main(argc, argv)
  char *argv[];
{
  var x, a, A;
  setlocale(LC_ALL, "");
  bestlineSetXlatCallback(bestlineUppercase);
  funcall = Apply;
  for (x = 1; x < argc; ++x) {
    if (argv[x][0] == '-' && argv[x][1] == 't') {
      funcall = Trace;
    } else {
      fputs("Usage: ", stderr);
      fputs(argv[0], stderr);
      fputs(" [-t] <input.lisp >errput.lisp\n", stderr);
      exit(1);
    }
  }
  LoadBuiltins();
  for (a = 0;;) {
    A = cx;
    if (!(x = setjmp(undefined))) {
      x = Read();
      if (x < 0 && Car(x) == kDefine) {
        a = Define(Cdr(x), a);
        SaveAlist(a);
        continue;
      }
      x = Eval(x, a, 0);
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
var eOutput, eEval, eReset, eLoad, eTrace, ePrograms, eDump;
var eGets, eSets, eMs, eAtoms, eCode, eHeap, eReads, eWrites, eClear;

function Throw(x) {
  throw x;
}

function Reset() {
  var i;
  a = 0;
  cx = 0;
  cHeap = 0;
  cGets = 0;
  cSets = 0;
  cReads = 0;
  cPrints = 0;
  Null = 16384;
  M = new Array(Null * 2);
  // for (i = 0; i < M.length; ++i) {
  //   M[i] = 0; /* make json smaller */
  // }
  Load("NIL T EQ CAR CDR ATOM COND CONS QUOTE DEFINE ");
  LoadBuiltins()
}

function PrintU16(c) {
  output += String.fromCharCode(c);
}

function IsHighSurrogate(c) {
  return (0xfc00 & c) == 0xd800;
}

function IsLowSurrogate(c) {
  return (0xfc00 & c) == 0xdc00;
}

function GetHighSurrogate(c) {
  return ((c - 0x10000) >> 10) + 0xD800;
}

function GetLowSurrogate(c) {
  return ((c - 0x10000) & 1023) + 0xDC00;
}

function ComposeUtf16(c, d) {
  return ((c - 0xD800) << 10) + (d - 0xDC00) + 0x10000;
}

function PrintChar(c) {
  if (c < 0x10000) {
    PrintU16(c);
  } else if (c < 0x110000) {
    PrintU16(GetHighSurrogate(c));
    PrintU16(GetLowSurrogate(c));
  } else {
    PrintU16(0xFFFD);
  }
}

function Ord(s) {
  var c, d;
  c = s.charCodeAt(0);
  if (IsHighSurrogate(c)) {
    if (code.length > 1 && IsLowSurrogate((d = s.charCodeAt(1)))) {
      c = ComposeUtf16(c, d);
    } else {
      c = 0xFFFD;
    }
  } else if (IsLowSurrogate(c)) {
    c = 0xFFFD;
  }
  return c;
}

function ReadChar() {
  var c, d, t;
  if (code.length) {
    if (index < code.length) {
      c = code.charCodeAt(index++);
      if (IsHighSurrogate(c)) {
        if (index < code.length &&
            IsLowSurrogate((d = code.charCodeAt(index)))) {
          c = ComposeUtf16(c, d), ++index;
        } else {
          c = 0xFFFD;
        }
      } else if (IsLowSurrogate(c)) {
        c = 0xFFFD;
      }
    } else {
      code = "";
      c = 0;
    }
    t = dx;
    dx = c;
    return t;
  } else {
    Throw(0);
  }
}

function Lisp() {
  var x, A, d, t;
  d = 0;
  cGets = 0;
  cSets = 0;
  cHeap = cx;
  cReads = 0;
  cPrints = 0;
  output = "";
  while (dx) {
    if (dx <= Ord(' ')) {
      ReadChar();
    } else {
      t = GetMillis();
      A = cx;
      try {
        x = Read();
        if (x < 0 && Car(x) == kDefine) {
          a = Define(Cdr(x), a);
          continue;
        }
        x = Eval(x, a, 0);
      } catch (z) {
        PrintChar(Ord('?'));
        x = z;
      }
      Print(x);
      PrintChar(Ord('\n'));
      Gc(A, 0);
      d += GetMillis() - t;
    }
  }
  eOutput.innerText = output;
  SaveAlist(a);
  SaveOutput();
  ReportUsage(d);
}

function Load(s) {
  index = 0;
  dx = Ord(' ');
  code = s + "\n";
}

function OnEval() {
  Load(g_editor.getValue());
  Lisp();
  SetStorage("input", g_editor.getValue());
}

function OnBeforeUnload() {
  SetStorage("input", g_editor.getValue());
}

function OnDump() {
  var t;
  output = "";
  t = GetMillis();
  DumpDefines(a);
  eOutput.innerText = output;
  t = GetMillis() - t;
  SaveOutput();
  ReportUsage(t);
}

function OnReset(e) {
  var t;
  output = "";
  t = GetMillis();
  try {
    if (!e.shiftKey) DumpDefines(a);
    eOutput.innerText = output;
    Reset();
  } catch (e) {
    /* ignored */
  }
  t = GetMillis() - t;
  RemoveStorage("alist");
  SaveOutput();
  ReportUsage(t);
}

function OnClear() {
  output = "";
  eOutput.innerText = output;
  SaveOutput();
  ReportUsage(0);
}

function OnTrace() {
  var t;
  Load(g_editor.getValue());
  t = panic;
  depth = 0;
  panic = 10000;
  funcall = Trace;
  Lisp();
  funcall = Apply;
  panic = t;
}

function OnLoad() {
  if (ePrograms.className == "dropdown-content") {
    ePrograms.className = "dropdown-content show";
  } else {
    ePrograms.className = "dropdown-content";
  }
}

function OnWindowClick(e) {
  if (e.target && !e.target.matches("#load")) {
    ePrograms.className = "dropdown-content";
  }
}

function OnWindowKeyDown(e) {
  if (e.key == "Escape") {
    ePrograms.className = "dropdown-content";
  }
}

function SaveAlist(a) {
  output = "";
  DumpAlist(a);
  SetStorage("alist", output);
}

function RestoreMachine() {
  var v;
  if ((v = GetStorage("output"))) {
    eOutput.innerText = v;
  }
  if ((v = GetStorage("input"))) {
    g_editor.setValue(v);
  }
  if ((v = GetStorage("alist"))) {
    Reset();
    Load(v);
    a = Compact(Read());
  } else if ((v = JSON.parse(GetStorage("machine")))) {
    M = v[0];
    a = v[1];
    cx = v[2];
    cHeap = cx;
  }
}

function SaveOutput() {
  SetStorage("input", g_editor.getValue());
  SetStorage("output", eOutput.innerText);
}

function FormatInt(i) {
  return i.toLocaleString();
}

function FormatDuration(d) {
  return d ? Math.round(d * 1000) / 1000 : 0;
}

function ReportUsage(ms) {
  var i, atom, code, heap;
  code = -cx >> 1;
  heap = -cHeap >> 1;
  for (atom = i = 0; i < Null / 2; ++i) {
    if (M[Null + i]) ++atom;
  }
  if (eGets) eGets.innerText = FormatInt(cGets);
  if (eSets) eSets.innerText = FormatInt(cSets);
  if (eMs) eMs.innerText = FormatInt(ms);
  if (eAtoms) eAtoms.innerText = FormatInt(atom);
  if (eCode) eCode.innerText = FormatInt(code);
  if (eHeap) eHeap.innerText = FormatInt(heap - code);
  if (eReads) eReads.innerText = FormatInt(cReads);
  if (ePrints) ePrints.innerText = FormatInt(cPrints);
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

function GetMillis() {
  if (typeof performance != "undefined") {
    return performance.now();
  } else {
    return 0;
  }
}

function GetStorage(k) {
  if (typeof localStorage != "undefined") {
    return localStorage.getItem(g_lisp + "." + k);
  } else {
    return null;
  }
}

function RemoveStorage(k) {
  if (typeof localStorage != "undefined") {
    localStorage.removeItem(g_lisp + "." + k);
  }
}

function SetStorage(k, v) {
  if (typeof localStorage != "undefined") {
    localStorage.setItem(g_lisp + "." + k, v);
  }
}

function SetUp() {
  funcall = Apply;
  Read = Discount(Read);
  Print = Discount(Print);
  Define = Discount(Define);
  eLoad = document.getElementById("load");
  eReset = document.getElementById("reset");
  eTrace = document.getElementById("trace");
  eOutput = document.getElementById("output");
  eEval = document.getElementById("eval");
  eClear = document.getElementById("clear");
  eDump = document.getElementById("dump");
  ePrograms = document.getElementById("programs");
  eGets = document.getElementById("cGets");
  eSets = document.getElementById("cSets");
  eMs = document.getElementById("cMs");
  eAtoms = document.getElementById("cAtoms");
  eCode = document.getElementById("cCode");
  eHeap = document.getElementById("cHeap");
  eReads = document.getElementById("cReads");
  ePrints = document.getElementById("cPrints");
  window.onkeydown = OnWindowKeyDown;
  if (window.onbeforeunload) window.onbeforeunload = OnBeforeUnload;
  if (ePrograms) window.onclick = OnWindowClick;
  if (eLoad) eLoad.onclick = OnLoad;
  if (eReset) eReset.onclick = OnReset;
  if (eTrace) eTrace.onclick = OnTrace;
  if (eEval) eEval.onclick = OnEval;
  if (eDump) eDump.onclick = OnDump;
  if (eClear) eClear.onclick = OnClear;
}

// `
#endif
//`
