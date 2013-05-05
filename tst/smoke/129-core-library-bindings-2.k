;; Test whether that the interpreter claims support of all
;; ground bindings from Revised(-1) Report on the Kernel
;; Programming Language chapter 6: Core library features (II).
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
    not? and? or? $and? $or?
    combiner?
    length list-ref append list-neighbors
      filter assoc member? finite-list? countable-list?
      reduce
    append! copy-es assq memq?
    eq? equal?
    $binds? get-current-environment make-kernel-standard-environment
      $let* $letrec $letrec* $let-redirect $let-safe
      $remote-eval $bindings->environment
    $set! $provide! $import!
    for-each))
