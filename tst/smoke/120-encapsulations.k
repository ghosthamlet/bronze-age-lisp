;; test (make-encapsulation-type)
($sequence
  ($define! (e1 p1 d1) (make-encapsulation-type))
  ($define! (e2 p2 d2) (make-encapsulation-type))
  ($define! x1 (e1 1))
  ($define! x2 (e2 2))
  (list
    (applicative? e1)
    (applicative? e2)
    (applicative? p1) (p1) (p1 x1) (p1 x2)
    (applicative? p2) (p2) (p2 x1) (p2 x2)
    (applicative? d1)
    (applicative? d2)
    (d1 x1) (d2 x2)))
