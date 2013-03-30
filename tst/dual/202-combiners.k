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
