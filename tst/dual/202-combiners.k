;; Check ($lambda ...) against derivation from $vau
;; from Kernel Report section 5.3.2
;;
($check $lambda
  ($vau (formals . body) env
    (wrap (eval (list* $vau formals #ignore body)
                env)))
  #inert
  ((operative? $lambda)
   (($lambda x x) 1 2 3)
   (($lambda (x y . z) (list z y x)) 5 6 7 8 9)))

;; Check (apply ...) against derivation
;; from Kernel Report section 5.5.1
;;
($check apply
  ($lambda (appv arg . opt)
    (eval (cons (unwrap appv) arg)
          ($if (null? opt) (make-environment) (car opt))))
  #inert
  ((applicative? apply)
   (apply list ())
   (apply list (list 1))
   (apply list (list 1 2))
   (apply list (list 1 2 3))
   (apply list (list 1 2 3 4))
   (apply (wrap $sequence) (list ($quote $if)))
   (apply (wrap $sequence)
          (list ($quote $if))
          (get-current-environment))))
