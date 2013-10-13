#! /bin/sh
set -e
mkdir -p build

#
# command line options for mold.k
#

CONF_DEBUG_ON='
  debug-evaluator=#t
  debug-gc-cycle=#t
  debug-gc-detail=#t
  debug-ports=#t
  debug-gc-blobs=#t
  debug-continuations=#t
  debug-environments=#t'

CONF_DEBUG_OFF='
  debug-evaluator=#f
  debug-gc-cycle=#f
  debug-gc-detail=#f
  debug-ports=#f
  debug-gc-blobs=#f
  debug-continuations=#f
  debug-environments=#f'

CONF_SMALLER_HEAP='
  lisp-heap-size=524288
  blob-heap-size=65536'

#
# command line options for the assembler
#
NASMFLAGS='-g -O1'

#
# The build interpreter (to build tests) and the reference interpreter (to check results).
#
BUILDINT=bronze-devel
REFINT=klisp
if [ ! -x `which $BUILDINT` ] ; then
    BUILDINT=$REFINT
fi

prepare_asm_test()
{
    echo "preparing asm tests..."

    $BUILDINT ../src/mold.k \
    'no-data-segment=#t' 'no-code-segment=#t' 'no-macros=#f' 'no-applicative-support=#t' \
    $CONF_DEBUG \
    'lisp-heap-size=1024' 'lisp-transient-size=192' 'lisp-heap-threshold=256' \
    'blob-descriptor-capacity=16' 'blob-heap-size=4096' \
    'src-prefix="../src/"' > build/macros.inc

    $BUILDINT ../src/mold.k \
    'no-data-segment=#t' 'no-code-segment=#t' 'no-macros=#t' 'no-applicative-support=#f' \
    $CONF_DEBUG \
    'lisp-heap-size=1024' 'lisp-transient-size=192' 'lisp-heap-threshold=256'  \
    'blob-descriptor-capacity=16' 'blob-heap-size=4096' \
    'src-prefix="../src/"' > build/applicative-support.inc
}

asm_test()
{
    echo -n "$1 ..."
    nasm -o build/test.o -f elf32 $NASMFLAGS $2 -i ../src/ -i asm/ -i build/ $1
    ld -o build/test.bin build/test.o -Tasm/linker-script.ld -Map=build/test.map
    ./build/test.bin
}

prepare_smoke_test()
{
    echo "preparing smoke tests..."
    $BUILDINT ../src/mold.k \
        $CONF_DEBUG \
        'start-form=(write (eval (read) (get-current-environment)))' \
        'src-prefix="../src/"' > build/smoke.asm
    nasm $NASMFLAGS -f elf32 -o build/smoke.o -i ../src/ -i asm/ -i build/ build/smoke.asm
    ld -o build/smoke.bin build/smoke.o -T../src/runtime/linker-script.ld
}

smoke_test()
{
    echo -n "$1 ..."
    build/smoke.bin <$1 >build/smoke.tmp
    if $REFINT smoke/check.k $1 <build/smoke.tmp ; then
      echo "PASS"
    else
      echo "FAIL"
    fi
}

prepare_dual_test()
{
    echo "preparing dual tests..."
    $BUILDINT ../src/mold.k \
        $CONF_DEBUG \
        $CONF_SMALLER_HEAP \
        'src-prefix="../src/"' > build/dual.asm
    nasm $NASMFLAGS -f elf32 -o build/dual.o -i ../src/ -i asm/ -i build/ build/dual.asm
    ld -o build/dual.bin build/dual.o -T../src/runtime/linker-script.ld
}

dual_test()
{
    echo -n "$1 ..."
    build/dual.bin dual/dual-test.k $1
}

self_test()
{
    echo -n "$1 ..."
    build/dual.bin -l self/self-test-support.k $1
}

prepare_bootstrap_test()
{
    echo "preparing bootstrap test..."
    $REFINT ../src/mold.k \
        $CONF_DEBUG \
        'src-prefix="../src/"' > build/bootstrap.asm
    nasm $NASMFLAGS -f elf32 -o build/bootstrap.o -i ../src/ -i asm/ -i build/ build/bootstrap.asm
    ld -o build/bootstrap.bin build/bootstrap.o -T../src/runtime/linker-script.ld
}

run_bootstrap_test()
{
    echo -n "bootstrap test ..."
    build/bootstrap.bin ../src/mold.k \
        $CONF_DEBUG \
        'src-prefix="../src/"' > build/bootstrap-out.asm
    if diff -i build/bootstrap-out.asm build/bootstrap.asm ; then
      echo 'PASS'
    else
      echo 'FAIL'
    fi
}

run_all_tests()
{
    prepare_asm_test
    for t in asm/[0-9]*.asm ; do
        asm_test $t
    done
    prepare_smoke_test
    for t in smoke/[0-9]*.k ; do
        smoke_test $t
    done
    prepare_dual_test
    for t in dual/[0-9]*.k ; do
        dual_test $t
    done
    for t in self/[0-9]*.k ; do
        self_test $t
    done
    prepare_bootstrap_test
    run_bootstrap_test
}

case "$1" in
    -n) CONF_DEBUG="$CONF_DEBUG_OFF"
        shift
        ;;
    -d) CONF_DEBUG="$CONF_DEBUG_ON"
        shift
        ;;
    *)  CONF_DEBUG="$CONF_DEBUG_OFF"
        ;;
esac

if [ $# -ne 0 ] ; then
    case "$1" in
    0??) prepare_asm_test
         asm_test asm/$1-*.asm -dVERBOSE
         ;;
    1??) prepare_smoke_test
         smoke_test smoke/$1-*.k
         ;;
    2??) prepare_dual_test
         dual_test dual/$1-*.k
         ;;
    3??) prepare_dual_test
         self_test self/$1-*.k
         ;;
    400) prepare_bootstrap_test
         run_bootstrap_test
         ;;
    *)   echo "usage: test.sh [NUMBER]" 1>&2
         exit 1
         ;;
    esac
else
    run_all_tests
fi
