;;
;; 05-nested-environments.k
;;

($define! nest
  ($lambda (n e1 e2)
    ($if (<? 0 n)
      (nest (- n 1) e1 (make-environment e1 e2))
      e2)))

($define! test
  ($lambda ()
    ($remote-eval
      (list x)
      (nest 8000
        ($bindings->environment (x 42))
        ($bindings->environment (list list))))))

(test) (test) (test) (test) (test) (test) (test)
(write (test))

