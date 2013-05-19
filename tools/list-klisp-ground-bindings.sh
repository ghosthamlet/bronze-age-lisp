#! /bin/sh
#

if [ $# -ne 2 ] ; then
  echo 'usage: list-klisp-ground-bindings.sh EXECUTABLE INTERPRETER' 1>&2
  echo '  e.g. list-klisp-ground-bindings.sh `which klisp` klisp' 1>&2
  echo '  e.g. list-klisp-ground-bindings.sh `which klisp` bronze.bin' 1>&2
  exit 1
fi

strings $1 | $2 \
  -e '($define! env (make-kernel-standard-environment))' \
  -e '($define! iter
        ($lambda ()
          ($define! line (read-line))
          ($unless (eof-object? line)
            ($define! s (string->symbol line))
            ($when ((wrap $binds?) env s)
              (write s)
              (newline))
            (iter))))' \
  -e '(iter)' | sort -u
