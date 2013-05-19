;; Test whether that the interpreter claims support of all
;; ground bindings from Revised(-1) Report on the Kernel
;; Programming Language chapters
;;
;;   7 Continuations
;;   8 Encapsulations
;;   9 Promises
;;  10 Keyed dynamic variables
;;  11 Keyed static variables
;;
;; and the section
;;
;;  12.5 Number features
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
    continuation? call/cc extend-continuation
      guard-continuation continuation->applicative
      root-continuation error-continuation
      apply-continuation $let/cc guard-dynamic-extent
      exit
    make-encapsulation-type
    promise? force $lazy memoize
    make-keyed-dynamic-variable
    make-keyed-static-variable
    number? finite? integer?
      =? <? <=? >=? >? + * - zero?
      div mod div-and-mod div0 mod0 div0-and-mod0
      positive? negative? odd? even?
      abs min max lcm gcd))
