;;;
;;; 304-basic-arithmetic.k
;;;
;;; Test arithmetic on small integers and exact infinities.
;;;

($unless ($binds? (get-current-environment) negate)
  ($define! negate ($lambda (x) (- 0 x))))

($define! test-list
  ($let ((pos (list 1 2 3 4 5 #e+infinity)))
    (append (list 0) pos (map negate pos))))

($define! for-each-2
  ($lambda (f xs)
    (for-each
      ($lambda (x)
        (for-each ($lambda (y) (apply f (list x y))) xs))
      xs)))

($define! for-each-3
  ($lambda (f xs)
    (for-each
      ($lambda (x)
        (for-each
          ($lambda (y)
            (for-each
              ($lambda (z)
                (apply f (list x y z)))
              xs))
          xs))
      xs)))

($define! $t
  ($vau (vars . body) denv
    ($let*
      ((funcsymb (string->symbol "F"))
       (testcode (eval (list* $lambda vars body) denv))
       (iterator ($cond
                   ((=? 1 (length vars)) for-each)
                   ((=? 2 (length vars)) for-each-2)
                   ((=? 3 (length vars)) for-each-3)))
       (testfunc ($lambda args
                   ($let ((r (protect-call testcode args)))
                     ($if (equal? r (list "return" #t))
                       (pass)
                       (fail-with-report
                         (list* (cons funcsymb vars) body)
                         (list* funcsymb args)
                         r #t))))))
      (iterator testfunc test-list))))

($define! $e
  ($vau (expr message) denv
    ($let* (((kind . results)
             (protect-eval expr (make-kernel-standard-environment)))
            (message (eval message denv)))
      ($if ($and? (equal? kind "error")
                  (equal? (car results) message))
        (pass)
        (fail-with-report
          "arithmetic error handling"
          expr
          (list* kind results)
          (list "error" message))))))

($define! $implies?
  ($vau (a b) denv
    ($or? (not? (eval a denv)) (eval b denv))))

($define! $eu
  ($vau (expr) denv
    (eval (list $e expr "Undefined arithmetic operation.") denv)))

;; positive? zero? negative?
;;
($t (x) (eq? (=? x 0) (zero? x)))
($t (x) (eq? (<? x 0) (negative? x)))
($t (x) (eq? (>? x 0) (positive? x)))
($t (x) (eq? (not? (zero? x)) (or? (positive? x) (negative? x))))

;; negate
;;
($t (x) (=? x (negate (negate x))))
($t (x) ($implies? (positive? x) (negative? (negate x))))

;; abs
;;
($t (x) (=? (abs x) (abs (negate x))))
($t (x) (<=? (negate (abs x)) x (abs x)))

;; (+ ...)
;;
($t (x) (=? x (+ x)))
($t (x) (=? x (+ 0 x)))
($t (x) ($implies? (finite? x) (zero? (+ x (negate x)))))
($t (x y) ($implies? (finite? x) (=? (+ x y) (+ y x))))
($t (x y) ($implies? (positive? x y) (positive? (+ x y))))
($t (x y) ($implies? (negative? x y) (negative? (+ x y))))
($t (x) (<=? x (+ x 1)))
($t (x) ($implies? (finite? x) (<? x (+ x 1))))
($t (x) ($implies? (finite? x) (=? #e+infinity (+ x #e+infinity))))

($eu (+ #e+infinity #e-infinity))

;; (- ...)
;;
($t (x) ($implies? (finite? x) (zero? (- x x))))
($t (x y) ($implies? ($or? (finite? x) (finite? y))
                     (=? (- x y) (negate (- y x)))))
($t (x y) ($implies? ($or? (finite? x) (finite? y))
                     (=? (- x y) (+ x (negate y)))))
($t (x) (>=? x (- x 1)))
($eu (- #e+infinity #e+infinity))

;; (* ...)
;;
($t (x) (=? x (* x)))
($t (x) (=? x (* 1 x)))
($t (x) ($implies? (finite? x) (zero? (* 0 x))))
($t (x) ($implies? (not? (zero? x)) (positive? (* x x))))

($t (x y) ($implies? ($or? (finite? x y)
                           ($and? (not? (zero? x)) (not? (zero? y))))
                     (=? (* x y) (* y x))))

($t (x y z) ($implies? (finite? x y z)
                       (=? (* x (+ y z)) (+ (* x y) (* x z)))))

($t (x y) ($implies? ($or? (positive? x y) (finite? x y))
                     (=? (* (+ x y) (+ x y)) (+ (* x x) (* 2 x y) (* y y)))))

($eu (* 0 #e+infinity))

(summary)
