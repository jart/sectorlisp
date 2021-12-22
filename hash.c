#ifndef __COSMOPOLITAN__
#include <stdio.h>
#include <stdlib.h>
#endif

#define word unsigned long

static word Null;

static inline int IsTwoPow(word x) {
  return !(x & (x - 1));
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
    if (Null < 64) {
      fprintf(stderr, "Error: Null is too small\n");
      return Usage(argv[0]);
    }
    if (!IsTwoPow(Null)) {
      fprintf(stderr, "Error: Null must be two power\n");
      return Usage(argv[0]);
    }
  } else {
    /* Null = 040000; */
    Null = 64;
  }
  for (;; Null <<= 1) {
    printf("\n");
    printf("#define Null %#lo\n", Null);
    fflush(stdout);
    for (a = 0; a < Null / 2; ++a) {
      for (c = 0; c <= Bsr(Null / 2) / 2; ++c) {
        /* for (b = 0; b < Null; ++b) { */
        /* solve 1 = ('T' * a + b) / 2^c for b */
        b = (((1<<c) - a * 'T') & (Null/2-1));
        if (Ok(a, b, c)) {
          if (c) {
            printf("return (((h + x) * %lu + %lu) >> %lu) & (Null/2-1);\n", a, b, c);
          } else {
            printf("return ((h + x) * %lu + %lu) & (Null/2-1);\n", a, b);
          }
        }
      }
    }
  }
  return 0;
}
