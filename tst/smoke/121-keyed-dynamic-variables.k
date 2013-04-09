;; test (make-keyed-dynamic-variable)
($sequence
  ($define! (b1 a1) (make-keyed-dynamic-variable))
  ($define! (b2 a2) (make-keyed-dynamic-variable))
  (list
    (applicative? b1)
    (applicative? a1)
    (b1 1
     ($lambda ()
       (list (a1)
             (b2 2
               ($lambda ()
                 (list (a1)
                       (a2)
                       (b1 3 ($lambda () (list (a1) (a2))))
                       (a1)
                       (a2))))
             (a1))))))
