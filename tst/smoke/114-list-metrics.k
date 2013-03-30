;; test get-list-metrics, list-ref, list-tail, encycle!
;; Warning: Printer does not support cycles yet.
($sequence
  ($define! a (list 1 2 3 4 5))
  ($define! b (list 1 2 3))
  (encycle! b 1 1)
  (list
    (get-list-metrics a)
    (get-list-metrics (list-tail a 0))
    (get-list-metrics (list-tail a 1))
    (get-list-metrics (list-tail a 2))
    (list-ref a 2)
    (get-list-metrics b)
    (get-list-metrics (list-tail a 0))
    (get-list-metrics (list-tail a 1))
    (get-list-metrics (list-tail a 2))
    (list-ref a 2)))
