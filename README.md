# sectorlisp

sectorlisp is an effort to bootstrap John McCarthy's meta-circular
evaluator on bare metal from a 512-byte boot sector.

![Yo dawg, I heard you like LISP so I put a LISP in your LISP so you can eval while you eval](bin/yodawg.png)

## Motivations

Much of the information about LISP online tends to focus on
[wild macros](http://www.paulgraham.com/onlisp.html),
[JIT compilation](http://pixielang.org/), or its merits as
[a better XML](http://www.defmacro.org/ramblings/lisp.html)
as well as [a better JSON](https://stopa.io/post/265). However
there's been comparatively little focus on the
[primary materials](https://people.cs.umass.edu/~emery/classes/cmpsci691st/readings/PL/LISP.pdf)
from the 1950's which emphasize the radically simple nature of
LISP, as best evidenced by the meta-circular evaluator above.

<p align="center">
  <img alt="Binary Footprint Comparison"
       width="750" height="348" src="bin/footprint.png">
</p>

This project aims to promote the radical simplicity of the essential
elements of LISP's original design, by building the tiniest LISP machine
possible. With a binary footprint less than one kilobyte, that's capable
of running natively without dependencies on modern PCs, sectorlisp might
be the tiniest self-hosting LISP interpreter to date. 

We're still far off however from reaching our goal, which is to have
sectorlisp be small enough to fit in the master boot record of a floppy
disk, like [sectorforth](https://github.com/cesarblum/sectorforth). If
you can help this project reach its goal, please send us a pull request!

## Demo

<p align="center">
  <a href="https://youtu.be/hvTHZ6E0Abo">
    <img alt="booting sectorlisp in emulator"
         width="960" height="540" src="bin/sectorlisp.gif"></a>
</p>

The video above demonstrates how to boot sectorlisp in the blinkenlights
emulator, to bootstrap the meta-circular evaluator, which evaluates a
program for finding the first element in a tree.

You can [watch the full demo on YouTube](https://youtu.be/hvTHZ6E0Abo).
