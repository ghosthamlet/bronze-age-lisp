;; test (append ...)
($sequence
  ($define! a (list 1 2 3 4 5))
  ($define! b (list 1 2 3))
  ($define! c (list a (list 6 7 8) a (list 9 9)))
  (encycle! b 1 2)
  (encycle! c 2 2)
  (list
    (append)
    (append a)
    (append a a)
    (append a a a)
    (get-list-metrics (append a b))
    (get-list-metrics (append a a b))
    (get-list-metrics (apply append c))))
