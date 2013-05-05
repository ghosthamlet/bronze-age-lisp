;; test (make-keyed-static-variable)
($sequence
  ($define! (b1 a1) (make-keyed-static-variable))
  ($define! (b2 a2) (make-keyed-static-variable))
  (list
    (applicative? b1)
    (applicative? a1)
    (eval (list a1)
          (b1 1 (make-environment)))
    (eval (list a1)
          (b1 2 (b1 3 (make-environment))))
    (eval (list list (list a1) (list a2))
          (b2 4 (b1 5 (make-environment))))
    ($let
      ((f ($remote-eval ($lambda (x) (+ (a1) x))
                        (b1 50 (get-current-environment)))))
      (f 6))))
