;; test of bytevector-copy-partial!
($let ((x (bytevector 0 1 2 3 4))
       (y (bytevector 5 6 7 8 9 10)))
  (list
    (bytevector-copy-partial! x 1 4 y 2)
    (bytevector->list x)
    (bytevector->list y)
    (bytevector-copy-partial! x 1 4 x 2)
    (bytevector->list x)
    (bytevector->list y)
    (bytevector-copy-partial! y 1 4 y 0)
    (bytevector->list x)
    (bytevector->list y)))
