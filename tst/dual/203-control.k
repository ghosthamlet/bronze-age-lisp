;; Check ($cond ...) against derivation from $vau
;; from Kernel Report section 5.6.1
;;
($check $cond
  ($vau clauses env
    ($define! aux
      ($lambda ((test . body) . clauses)
        ($if (eval test env)
             (apply (wrap $sequence) body env)
             (apply (wrap $cond) clauses env))))
    ($if (null? clauses)
      #inert
      (apply aux clauses)))
  #inert
  ((operative? $cond)
   ($cond)
   ($cond #t #f)
   ($cond (#t 1) (#f blabla))
   ($cond (#f quaqua) (#t 4))
   ($cond ((not? #t) (not? #f)) ((not? #f) (not? #t)))))
