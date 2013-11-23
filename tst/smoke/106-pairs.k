;; test basic pair manipulation
(list
  (pair?) ((unwrap pair?))
  (pair? ()) (null? ())
  (pair? (cons 0 0)) (null? (cons 0 0))
  (car (cons 1 2))
  (cdr (cons 2 3))
  (caar (cons (cons 4 5) (cons 6 7)))
  (cadr (cons (cons 8 9) (cons 10 11)))
  (cdar (cons (cons 12 13) (cons 14 15)))
  (cddr (cons (cons 16 17) (cons 18 19))))
