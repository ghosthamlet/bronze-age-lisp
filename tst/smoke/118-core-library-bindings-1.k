;; Test whether that the interpreter claims support of all
;; ground bindings from Revised(-1) Report on the Kernel
;; Programming Language chapter 5: Core library features (I).
;;
($sequence
  ($define! $have-symbol?
    ($vau (symbol) denv
      (list symbol
            (eval (list $binds? denv symbol)
                  (make-environment)))))
  ($define! $show
    ($vau symbols denv
      ($if (pair? symbols)
        (cons
          (eval (list $have-symbol? (car symbols)) denv)
          (eval (cons $show (cdr symbols)) denv))
        ())))
  ($show
    $sequence
    list list*
    $vau $lambda
    car cdr
    caar cadr cdar cddr
    caaar caadr cadar caddr cdaar cdadr cddar cdddr
    caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
    cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr
    apply
    $cond
    get-list-metrics
    list-tail
    encycle!
    map
    $let))
