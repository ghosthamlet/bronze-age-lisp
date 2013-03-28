;; test list operations
(list
  (list) (list 1) (list 2 3) (list 4 5 6) (list 7 8 9 10)
  (list* 11) (list* 12 13) (list* 14 15 16); (list* 17 18 19 20)
  (length ()) (length (cons 21 ())) (length (list 22 23 24))
  (memq? 1 ())
  (memq? 1 (list 1))
  (memq? 1 (list 2))
  (memq? 1 (list 1 2))
  (memq? 1 (list 0 2 3))
  (assoc #t ())
  (assoc #t (list (cons #t 4)))
  (assoc #t (list (cons #f 4)))
  (assoc #t (list (cons #f 2) (cons #t 4) (cons #t 5))))
