;; basic test of bytevector constructors
($let* ((x (bytevector 1 2 3 4 5))
        (y (bytevector-copy x))
        (#ignore (bytevector-u8-set! x 2 10))
        (z (bytevector-copy x)))
  (list
    (bytevector->list x)
    (bytevector->list y)
    (bytevector->list z)
    (list (eq? x y) (eq? x z) (eq? y z))
    (list (equal? x y) (equal? x z) (equal? y z))))
