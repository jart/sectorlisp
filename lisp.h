#ifndef SECTORLISP_H_
#define SECTORLISP_H_
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>

/*───────────────────────────────────────────────────────────────────────────│─╗
│ The LISP Challenge § Richard Stallman Math 55 Systems Integration Code   ─╬─│┼
╚────────────────────────────────────────────────────────────────────────────│*/

#define CompilerBarrier() asm volatile("" ::: "memory")

#define ISATOM(x) /* a.k.a. !(x&1) */                        \
  ({                                                         \
    _Bool IsAtom;                                            \
    asm("test%z1\t$1,%1" : "=@ccnz"(IsAtom) : "Qm"((char)x)); \
    IsAtom;                                                  \
  })

#define OBJECT(t, v) /* a.k.a. v<<1|t */ \
  ({                                     \
    __typeof(v) Val = (v);               \
    asm("shl\t%0" : "+r"(Val));          \
    Val | (t);                           \
  })

#define SUB(x, y) /* a.k.a. x-y */           \
  ({                                         \
    __typeof(x) Reg = (x);                   \
    asm("sub\t%1,%0" : "+rm"(Reg) : "g"(y)); \
    Reg;                                     \
  })

#define STOS(di, c) asm("stos%z1" : "+D"(di), "=m"(*(di)) : "a"(c))
#define LODS(si)                                     \
  ({                                                 \
    typeof(*(si)) c;                                 \
    asm("lods%z2" : "+S"(si), "=a"(c) : "m"(*(si))); \
    c;                                               \
  })

static inline void *SetMemory(void *di, int al, unsigned long cx) {
  asm("rep stosb"
      : "=D"(di), "=c"(cx), "=m"(*(char(*)[cx])di)
      : "0"(di), "1"(cx), "a"(al));
  return di;
}

static inline void *CopyMemory(void *di, const void *si, unsigned long cx) {
  asm("rep movsb"
      : "=D"(di), "=S"(si), "=c"(cx), "=m"(*(char(*)[cx])di)
      : "0"(di), "1"(si), "2"(cx));
  return di;
}

static void RawMode(void) {
#ifndef __REAL_MODE__
  struct termios t;
  if (ioctl(1, TCGETS, &t) != -1) {
    t.c_cc[VMIN] = 1;
    t.c_cc[VTIME] = 1;
    t.c_iflag &= ~(INPCK | ISTRIP | PARMRK | INLCR | IGNCR | ICRNL | IXON);
    t.c_lflag &= ~(IEXTEN | ICANON | ECHO | ECHONL);
    t.c_cflag &= ~(CSIZE | PARENB);
    t.c_oflag &= ~OPOST;
    t.c_cflag |= CS8;
    t.c_iflag |= IUTF8;
    ioctl(1, TCSETS, &t);
  }
#endif
}

__attribute__((__noinline__)) static void PrintChar(long c) {
#ifdef __REAL_MODE__
  asm volatile("mov\t$0x0E,%%ah\n\t"
               "int\t$0x10"
               : /* no outputs */
               : "a"(c), "b"(7)
               : "memory");
#else
  static short buf;
  int rc;
  buf = c;
  write(1, &buf, 1);
#endif
}

static int ReadChar(void) {
  int c;
#ifdef __REAL_MODE__
  asm volatile("int\t$0x16" : "=a"(c) : "0"(0) : "memory");
  c &= 0xff;
#else
  static int buf;
  read(0, &buf, 1);
  c = buf;
#endif
  return c;
}

#define PEEK_(REG, BASE, INDEX, DISP)                                    \
  ({                                                                     \
    __typeof(*(BASE)) Reg;                                               \
    if (__builtin_constant_p(INDEX) && !(INDEX)) {                       \
      asm("mov\t%c2(%1),%0"                                              \
          : REG(Reg)                                                     \
          : "bDS"(BASE), "i"((DISP) * sizeof(*(BASE))),                  \
            "m"(BASE[(INDEX) + (DISP)]));                                \
    } else {                                                             \
      asm("mov\t%c3(%1,%2),%0"                                           \
          : REG(Reg)                                                     \
          : "b"(BASE), "DS"((long)(INDEX) * sizeof(*(BASE))),            \
            "i"((DISP) * sizeof(*(BASE))), "m"(BASE[(INDEX) + (DISP)])); \
    }                                                                    \
    Reg;                                                                 \
  })

#define PEEK(BASE, INDEX, DISP) /* a.k.a. b[i] */        \
  (sizeof(*(BASE)) == 1 ? PEEK_("=Q", BASE, INDEX, DISP) \
                        : PEEK_("=r", BASE, INDEX, DISP))

#define PEEK_ARRAY_(REG, OBJECT, MEMBER, INDEX, DISP)                     \
  ({                                                                      \
    __typeof(*(OBJECT->MEMBER)) Reg;                                      \
    if (!(OBJECT)) {                                                      \
      asm("mov\t%c2(%1),%0"                                               \
          : REG(Reg)                                                      \
          : "bDS"((long)(INDEX) * sizeof(*(OBJECT->MEMBER))),             \
            "i"(__builtin_offsetof(__typeof(*(OBJECT)), MEMBER) +         \
                sizeof(*(OBJECT->MEMBER)) * (DISP)),                      \
            "m"(OBJECT->MEMBER));                                         \
    } else {                                                              \
      asm("mov\t%c3(%1,%2),%0"                                            \
          : REG(Reg)                                                      \
          : "b"(OBJECT), "DS"((long)(INDEX) * sizeof(*(OBJECT->MEMBER))), \
            "i"(__builtin_offsetof(__typeof(*(OBJECT)), MEMBER) +         \
                sizeof(*(OBJECT->MEMBER)) * (DISP)),                      \
            "m"(OBJECT->MEMBER));                                         \
    }                                                                     \
    Reg;                                                                  \
  })

#define PEEK_ARRAY(OBJECT, MEMBER, INDEX, DISP) /* o->m[i] */ \
  (sizeof(*(OBJECT->MEMBER)) == 1                             \
       ? PEEK_ARRAY_("=Q", OBJECT, MEMBER, INDEX, DISP)       \
       : PEEK_ARRAY_("=r", OBJECT, MEMBER, INDEX, DISP))

#define POKE_ARRAY_(REG, OBJECT, MEMBER, INDEX, DISP, VALUE)        \
  do {                                                              \
    if (!(OBJECT)) {                                                \
      asm("mov\t%1,%c3(%2)"                                         \
          : "=m"(OBJECT->MEMBER)                                    \
          : REG((__typeof(*(OBJECT->MEMBER)))(VALUE)),              \
            "bDS"((long)(INDEX) * sizeof(*(OBJECT->MEMBER))),       \
            "i"(__builtin_offsetof(__typeof(*(OBJECT)), MEMBER) +   \
                sizeof(*(OBJECT->MEMBER)) * (DISP)));               \
    } else {                                                        \
      asm("mov\t%1,%c4(%2,%3)"                                      \
          : "=m"(OBJECT->MEMBER)                                    \
          : REG((__typeof(*(OBJECT->MEMBER)))(VALUE)), "b"(OBJECT), \
            "DS"((long)(INDEX) * sizeof(*(OBJECT->MEMBER))),        \
            "i"(__builtin_offsetof(__typeof(*(OBJECT)), MEMBER) +   \
                sizeof(*(OBJECT->MEMBER)) * (DISP)));               \
    }                                                               \
  } while (0)

#define POKE_ARRAY(OBJECT, MEMBER, INDEX, DISP, VALUE) /* o->m[i]=v */ \
  do {                                                                 \
    __typeof(*(OBJECT->MEMBER)) Reg;                                   \
    switch (sizeof(*(OBJECT->MEMBER))) {                               \
      case 1:                                                          \
        POKE_ARRAY_("Q", OBJECT, MEMBER, INDEX, DISP, VALUE);          \
        break;                                                         \
      default:                                                         \
        POKE_ARRAY_("r", OBJECT, MEMBER, INDEX, DISP, VALUE);          \
        break;                                                         \
    }                                                                  \
  } while (0)

#endif /* SECTORLISP_H_ */
