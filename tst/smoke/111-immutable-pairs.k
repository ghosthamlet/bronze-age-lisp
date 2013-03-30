;; test immutable pairs
(list
  (mutable-pair? ())
  (immutable-pair? ())
  (mutable-pair? (cons 1 2))
  (immutable-pair? (cons 1 2))
  (mutable-pair? (copy-es-immutable (cons 1 2)))
  (immutable-pair? (copy-es-immutable (cons 1 2))))
