#! /bin/sh

set -e
mkdir -p build

klisp mold.k "$@" > build/out.asm
nasm -g -felf32 -o build/out.o build/out.asm
ld -o build/bronze.bin build/out.o -Truntime/linker-script.ld
ls -l build/bronze.bin

