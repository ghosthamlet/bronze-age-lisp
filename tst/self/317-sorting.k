;;;
;;; 317-sorting.k
;;;
;;; Test sorting functions.
;;;

($define! $test-sort
  ($vau (rest xs ys) denv
    ($define! exp1 (list* (unwrap sort) xs (eval (cons list rest) denv)))
    ($define! sut1 (protect-eval exp1 denv))
    ($if (equal? sut1 (list "return" ys))
      (pass)
      (fail-with-report "sort" exp1 sut1 ys))
    ($define! exp2 (list* (unwrap sorted?) ys (eval (cons list rest) denv)))
    ($define! sut2 (protect-eval exp2 denv))
    ($if (equal? sut2 (list "return" #t))
      (pass)
      (fail-with-report "sorted?" exp2 sut2 #t))))

($define! $test-not-sorted
  ($vau (rest xs) denv
    ($define! exp (list* (unwrap sorted?) xs (eval (cons list rest) denv)))
    ($define! sut (protect-eval exp denv))
    ($if (equal? sut (list "return" #f))
      (pass)
      (fail-with-report "sorted?" exp sut #f))))

($test-sort (<?) () ())
($test-sort (<?) (1) (1))
($test-sort (<?) (1 2) (1 2))
($test-sort (<?) (2 1) (1 2))
($test-sort (<?) (1 2 3) (1 2 3))
($test-sort (<?) (1 3 2) (1 2 3))
($test-sort (<?) (2 1 3) (1 2 3))
($test-sort (<?) (2 3 1) (1 2 3))
($test-sort (<?) (3 1 2) (1 2 3))
($test-sort (<?) (3 2 1) (1 2 3))

($test-sort (<? car) ((5 x) (3 y)) ((3 y) (5 x)))
($test-sort (<? car) ((1 x) (2 y) (1 z) (2 w)) ((1 x) (1 z) (2 y) (2 w)))

($test-not-sorted (<?) (3 2))
($test-not-sorted (<? cdr) ((x . 10) (x . 11) (x . 10)))

(summary)
