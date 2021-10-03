#!/bin/sh
set -e
FILE=$1
[ -z "$FILE" ] && FILE=test1.lisp
[ -r "$FILE" ] || (echo "cannot read file: $FILE"; exit 1)
SIZE=$(wc -c "$FILE" | cut -d' ' -f1)
QEMU="qemu-system-x86_64"
QIMG="-drive file=../bin/sectorlisp.bin,index=0,if=floppy,format=raw -boot a"
QMON="-monitor tcp:127.0.0.1:55555,server,nowait"

trap 'echo quit | nc -N 127.0.0.1 55555' EXIT
cat "$FILE" | tr '\n' '\r' | ./tcat | \
	$QEMU -display curses -net none $QMON $QIMG &
PID=$!
SECS=$((1 + SIZE * 40 / 1000))
sleep $SECS
