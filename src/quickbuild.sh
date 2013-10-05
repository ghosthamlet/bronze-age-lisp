#! /bin/sh
#
# quickbuild.sh
#
# Build the interpreter. This script runs somewhat faster than build.sh.
#

set -e
mkdir -p build

# Build the interpreter using the previous version of Bronze Age Lisp,
# if it is installed in the system. Otherwise, use klisp.
#
if [ -x `which bronze-devel` ] ; then INTERP=bronze-devel
elif [ -x `which bronze-0.2` ] ; then INTERP=bronze-0.2
else INTERP=klisp ; fi
$INTERP mold.k "$@" > build/out.asm

# Run NASM with lower level of optimizations.
#
nasm -O1 -g -felf32 -o build/out.o build/out.asm

ld -o build/bronze.bin build/out.o -Truntime/linker-script.ld
ls -l build/bronze.bin

