#! /bin/sh
#
# usage: ./benchmark.sh
#
# Runs all benchmark programs.
#
KLISP=klisp
BRONZE=../src/build/bronze.bin
GNUTIME=/usr/bin/time
TMPDIR=/tmp

tmp=$TMPDIR/benchmark.tmp
o1=$TMPDIR/o1
o2=$TMPDIR/o2

echo -n ';; ' ; grep -i name /proc/cpuinfo | sort -u | cut -d: -f2
echo -n ';; ' ; $KLISP -v
echo -n ';; ' ; $BRONZE -v

rm -f $tmp $o1 $o2
for script in [0-9]*.k ; do
    echo "(\"$script\"" 1>&2
    /usr/bin/time \
      --format="  (#:klisp  (%U %S %e) %M)" \
      $KLISP $script $tmp > $o1
    /usr/bin/time \
      --format="  (#:bronze (%U %S %e) %M))" \
      $BRONZE $script $tmp > $o2
    if ! diff $o1 $o2 ; then
        echo 'Difference in output! Benchmark aborted.' 1>&2
        exit 1
    fi
done
rm -f $tmp $o1 $o2

