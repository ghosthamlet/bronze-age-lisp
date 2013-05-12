;;
;; 09-flat-environments.k
;;
;; Benchmark for symbol lookup.
;;

($define! make-symbol
  ($lambda (n)
    (string->symbol
      (string-append "x" (number->string n)))))

($define! make-bindings
  ($lambda (n a)
    ($if (>? n 0)
      (make-bindings (- n 1)
                     (cons (list (make-symbol n) n) a))
      a)))

($define! env
  (make-environment
    (eval (cons $bindings->environment
                (make-bindings 5000 ()))
          (make-kernel-standard-environment))
    (make-kernel-standard-environment)))

($define! $get
  ($vau (sym) #ignore
    (eval sym env)))

($define! test
  ($remote-eval
    ($sequence
     ($define! u 1)
      ($define! test
        ($lambda (n)
          x1 x1000 x2000 x3000 x4000 x5000
          ($when (positive? n) (test (- n 1)))))
      test)
    env))

(write ($remote-eval (list x1 x2500 x5000) env))
(test 1500)


