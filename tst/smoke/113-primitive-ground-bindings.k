;; Test whether that the interpreter claims support of all
;; ground bindings from Revised(-1) Report on the Kernel
;; Programmin Language chapter 4: Core types and primitive
;; features.
;;
;; The interpreter must also support the bindings $sequence,
;; list and $binds?, which are not primitive in Kernel Report.
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
    boolean?
    eq? equal?
    symbol?
    inert? $if
    pair? null? cons?
    set-car! set-cdr! copy-es-immutable
    environment? ignore? eval make-environment
    $define!
    operative? applicative? $vau wrap unwrap))
