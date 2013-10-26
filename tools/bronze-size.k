;;;
;;; bronze-size.k
;;;
;;; Compute size of various parts of the interpreter,
;;; based on analysis of unstripped interpreter executable.
;;;
;;; usage: bronze.bin bronze-size.k bronze.bin
;;;

($define! prefixes
  (list "rn_" "app_" "primop_" "op_" "pred_" "siphash_" "gc_" "bl_"
        "alphabetic_" "white_space_" "unicode_" "utf" "cb_"
        "rom_string_" "rom_object_" "rom_pair_"))

($define! counters
  (map ($lambda (x) (list x 0 0)) prefixes))

($define! string-prefix?
  ($lambda (a b)
    ($let ((n (string-length a)) (m (string-length b)))
      ($and? (<=? n m) (equal? a (substring b 0 n))))))

($define! add!
  ($case-lambda
    ((name size ())
      #inert)
    ((name size ((c . v) . cs))
      ($if (string-prefix? c name)
        (add-v size v)
        (add! name size cs)))))

($define! add-v
  ($lambda (size v)
    ($define! (n s) v)
    (list-set! v 0 (+ n 1))
    (list-set! v 1 (+ s size))))

($define! process
  ($lambda ((addr section name)
            (next-addr next-section #ignore))
    ($define! sz (- next-addr addr))
    ($when ($and? (integer? section) (equal? section next-section) (positive? sz))
      (add! name sz counters))))

($define! (#ignore exe) (get-script-arguments))

($with-subshell
  (string-append
    "readelf -a " exe
    "| awk 'NF==8 && $1 ~ /[0-9]:$/ { printf(\"(#x%s %s \\\"%s\\\")\\n\", $2, $7, $8) }'")
  ((stdout f))
  ($define! loop
    ($lambda (prev)
      ($define! this (read f))
      ($when (pair? this)
        ($when (pair? prev) (process prev this))
        (loop this))))
  (loop ()))

(format #t "; (label-prefix count size-in-bytes)~%")
(for-each
  ($lambda (x) (format #t "~w~%" x))
  counters)
(format #t "; total size ~w bytes~%" (apply + (map caddr counters)))

