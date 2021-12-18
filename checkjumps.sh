#!/bin/sh
if objdump -Cwd -Mi8086 sectorlisp.o | cat -n |
    grep '[[:xdigit:]][[:xdigit:]] [[:xdigit:]][[:xdigit:]] [[:xdigit:]][[:xdigit:]][[:space:]]*j'; then
  echo need to shuffle code around >&2
  exit 1
else
  echo all jump encodings are tiny >&2
fi
