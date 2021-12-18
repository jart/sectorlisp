#ifndef __COSMOPOLITAN__
#include <stdio.h>
#include <stdlib.h>
#endif

#define word unsigned long
#define dubs unsigned __int128

struct Bar {
  dubs r;
  word n;
  char k;
};

static word Null;

static inline int IsTwoPow(word x) {
  return !(x & (x - 1));
}

static inline int Bsf(word x) {
#if defined(__GNUC__) && !defined(__STRICT_ANSI__)
  return __builtin_ctzll(x);
#else
  uint32_t l, r;
  x &= -x;
  l = x | x >> 32;
  r = !!(x >> 32), r <<= 1;
  r += !!(l & 0xffff0000), r <<= 1;
  r += !!(l & 0xff00ff00), r <<= 1;
  r += !!(l & 0xf0f0f0f0), r <<= 1;
  r += !!(l & 0xcccccccc), r <<= 1;
  r += !!(l & 0xaaaaaaaa);
  return r;
#endif
}

static inline int Bsr(word x) {
#if defined(__GNUC__) && !defined(__STRICT_ANSI__)
  return __builtin_clzll(x) ^ 63;
#else
  static const char kDebruijn[64] = {
      0,  47, 1,  56, 48, 27, 2,  60, 57, 49, 41, 37, 28, 16, 3,  61,
      54, 58, 35, 52, 50, 42, 21, 44, 38, 32, 29, 23, 17, 11, 4,  62,
      46, 55, 26, 59, 40, 36, 15, 53, 34, 51, 20, 43, 31, 22, 10, 45,
      25, 39, 14, 33, 19, 30, 9,  24, 13, 18, 8,  12, 7,  6,  5,  63,
  };
  x |= x >> 1;
  x |= x >> 2;
  x |= x >> 4;
  x |= x >> 8;
  x |= x >> 16;
  x |= x >> 32;
  return kDebruijn[(x * 0x03f79d71b4cb0a89) >> 58];
#endif
}

static inline word Log(word x) {
  return --x ? Bsr(x) + 1 : 0;
}

static struct Bar Bar(word n) {
  struct Bar m;
  m.r = 1;
  m.n = n;
  m.k = Log(n) << 1;
  m.r = (m.r << m.k) / n;
  return m;
}

static word Mod(struct Bar m, dubs x) {
  dubs t;
  t = x - ((x * m.r) >> m.k) * m.n;
  if (t >= m.n) t -= m.n;
  return t;
}

static word Mul(struct Bar m, word x, word y) {
  dubs t = x;
  return Mod(m, t * y);
}

static word Pow(struct Bar m, word a, word n) {
  word p, r;
  for (p = a, r = 1; n; n >>= 1) {
    if (n & 1) r = Mul(m, r, p);
    p = Mul(m, p, p);
  }
  return r;
}

static int W(struct Bar m, word a) {
  word x, y, s;
  s = Bsf(m.n >> 1) + 1;
  x = Pow(m, a, m.n >> s);
  for (y = 0; s; --s, x = y) {
    y = Mul(m, x, x);
    if (y == 1 && x != 1 && x != m.n - 1) {
      return 0;
    }
  }
  return y == 1;
}

static int MillerTime(word n) {
  struct Bar m;
  if (n < 2) return 0;
  if (n <= 3) return 1;
  if (~n & 1) return 0;
  if (n % 3 == 0) return 0;
  m = Bar(n);
  if (n < 1373653) return W(m,2) && W(m,3);
  if (n < 9080191) return W(m,31) && W(m,73);
  if (n < 4759123141) return W(m,2) && W(m,7) && W(m,61);
  if (n < 1122004669633) return W(m,2) && W(m,13) && W(m,23) && W(m,1662803);
  if (n < 2152302898747) return W(m,2) && W(m,3) && W(m,5) && W(m,7) && W(m,11);
  if (n < 3474749660383) return W(m,2) && W(m,3) && W(m,5) && W(m,7) && W(m,11) && W(m,13);
  return W(m,2) && W(m,3) && W(m,5) && W(m,7) && W(m,11) && W(m,13) && W(m,17);
}

static word Hash(word h, word x, word a, word b, word c) {
  return (((h + x) * a + b) >> c) & (Null / 2 - 1);
}

static word Ok(word a, word b, word c) {
  return Hash(Hash(Hash(0, 'L', a, b, c), 'I', a, b, c), 'N', a, b, c) == 0 &&
         Hash(0, 'T', a, b, c) == 1 &&
         Hash(0, 'T', a, b, c) != Hash(0, 'U', a, b, c);
}

static int Usage(const char *prog) {
  fprintf(stderr, "Usage: %s NULL\n", prog);
  fprintf(stderr, "Finds magic numbers for SectorLISP Hash()\n");
  return 1;
}

int main(int argc, char *argv[]) {
  word a, b, c;
  if (argc > 1) {
    Null = strtoul(argv[1], 0, 0);
    if (Null < 128) {
      fprintf(stderr, "Error: Null is too small\n");
      return Usage(argv[0]);
    }
    if (!IsTwoPow(Null)) {
      fprintf(stderr, "Error: Null must be two power\n");
      return Usage(argv[0]);
    }
  } else {
    Null = 040000;
  }
  for (a = 2; a < Null; ++a) {
    if (!MillerTime(a)) continue;
    for (c = 0; c <= Bsr(Null / 2); ++c) {
      for (b = 0; b < Null; ++b) {
        if (Ok(a, b, c)) {
          printf("return (((h + x) * %lu + %lu) >> %lu) & %#lo;\n", a, b, c,
                 Null / 2 - 1);
        }
      }
    }
  }
  return 0;
}
