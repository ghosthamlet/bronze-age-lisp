#! /bin/sh
#
# Make heap image executable.
#

if [ $# -ne 2 ] ; then
  echo 'usage: executable-heap-image IMAGE.heap PATH-TO-INTERPRETER' 1>&2
  echo '  e.g. executable-heap-image heap-image.heap `realpath ../src/build/bronze.bin`' 1>&2
  exit 1
fi

/bin/echo -e "#! $2 -H\n# interpreter: Bronze Age Lisp 0.3" \
  | dd of="$1" conv=notrunc bs=256 count=1
chmod a+x "$1" 
