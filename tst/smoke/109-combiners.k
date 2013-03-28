;; basic combiner operations
($sequence
  ($define! v1 ($vau (x y) e x))
  ($define! v2 ($vau (x y) e y))
  ($define! v3 ($vau (x y) e e))
  ($define! v4 ($vau (t) #ignore (v3 0 0)))
  ($define! f1 ($lambda (x y) x))
  ($define! f2 ($lambda (x y) y))
  ($define! t 42)
  (list
    (v1 (+ 1 2) (+ 3 4))
    ((wrap v1) (+ 5 6) (+ 7 8))
    (v2 3 4)
    (f1 (+ 1 2) (+ 3 4))
    (f2 3 4)
    (eval ((unwrap list) . t) (get-current-environment))
    (eval ((unwrap list) . t) (v3 7 8))
    (eval ((unwrap list) . t) (v4 52))))
