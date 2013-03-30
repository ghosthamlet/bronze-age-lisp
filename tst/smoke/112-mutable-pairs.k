;; test mutable pairs
($sequence
  ($define! (a b) (list (cons 1 2) (cons 3 4)))
  ($define! c (copy-es-immutable a))
  (set-car! a b)
  (set-cdr! b 5)
  (list a b c))
