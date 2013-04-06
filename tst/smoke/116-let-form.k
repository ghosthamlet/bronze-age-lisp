;; basic test of ($let ...)
(list
  (operative? $let)
  ($let () #t)
  ($let () #t #f)
  ($let ((x 42)) (list x x))
  ($let ((x 42) (y 53)) (list x y x y))
  ($let () ($define! x 5) x ($let () ($define! x 7) x) x)
  ($let ((x 5) (y 6)) ($let ((x y) (y x)) (list x y))))
