;;
;; 12-pidigits-stream.k
;;
;; Another port of the "pidigits" benchmark. This version follows
;; the C language implementation from
;;
;;   http://benchmarksgame.alioth.debian.org/u64/program.php?test=pidigits&lang=gcc&id=1
;;

($define! n 300)

($define! $let-mutable
  ($vau (eformal bindings . body) denv
    (eval (list* $let bindings
                 (list $define! eformal (list get-current-environment))
                 body)
          denv)))

($define! $def!
  ($vau (name . args-body) denv
    (eval (list $define! name (eval (list* $lambda args-body) denv))
          denv)))

($define! $while
  ($vau (expr . body) denv
    ($define! loop (list $when expr (list* $sequence body) #ignore))
    (set-car! (list-tail loop 3) loop)
    (eval loop denv)))

($let-mutable vars ((tmp1 0) (tmp2 0) (acc 0) (den 1) (num 1)
                    (i 0) (k 0))
  ($def! extract-digit (nth)
    ($set! vars tmp1 (* num nth))
    ($set! vars tmp2 (+ tmp1 acc))
    ($set! vars tmp1 (div tmp2 den))
    tmp1)
  ($def! eliminate-digit (d)
    ($set! vars acc (- acc (* den d)))
    ($set! vars acc (* acc 10))
    ($set! vars num (* num 10)))
  ($def! next-term (k)
    ($define! k2 (+ (* k 2) 1))
    ($set! vars acc (+ acc (* num 2)))
    ($set! vars acc (* acc k2))
    ($set! vars den (* den k2))
    ($set! vars num (* num k)))
  ($while (<? i n)
    ($set! vars k (+ k 1))
    (next-term k)
    ($unless (>? num acc)
      ($define! d (extract-digit 3))
      ($when (=? d (extract-digit 4))
        (write-char (digit->char d))
        ($set! vars i (+ i 1))
        ($when (=? 0 (mod i 10))
          (display "\t:") (display i) (newline))
        (eliminate-digit d)))))
