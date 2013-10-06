;;;
;;; 312-filter-partition.k
;;;
;;; Test list processing combiners.
;;;

($define! $equal?
  ($vau xs denv
    ($define! ys
      (map ($lambda (x) (protect-eval x denv)) xs))
    ($if ($and? (apply equal? (cons "return" (map car ys)))
                (apply equal? (map cadr ys)))
      (pass)
      (fail-with-report "lists"
        xs ys (list (car xs) ($quote |...|))))))

($define! $quoted-test-cases
  ($vau ((combiner . prefix) . args) denv
    ($define! f (eval combiner denv))
    ($define! p (eval (cons list prefix) denv))
    ($define! loop
      ($case-lambda
        (((in ref . t))
          ($define! env (make-kernel-standard-environment))
          ($define! arglist (append p (list in)))
          ($define! sut (protect-call f arglist))
          ($if (equal? sut (list "return" ref))
            (pass)
            (fail-with-report
              (symbol->string combiner)
              (cons f arglist) sut ref))
          (loop t))
        ((())
          #inert)
        (t
          (error "$quoted-test-cases" t))))
    (loop args)))

;;
;; (list-tabulate N F)
;;
($equal? (list)         (list-tabulate 0 negate))
($equal? (list 0)       (list-tabulate 1 negate))
($equal? (list 0 -1)    (list-tabulate 2 negate))
($equal? (list 0 -1 -2) (list-tabulate 3 negate))

;;
;; (iota COUNT [START [STEP]])
;;
($equal? () (iota 0))
($equal? () (iota 0 1))
($equal? () (iota 0 1 2))

($equal? (list 0) (iota 1))
($equal? (list 1) (iota 1 1))
($equal? (list 2) (iota 1 2 3))

($equal? (list 0 1) (iota 2))
($equal? (list 1 2) (iota 2 1))
($equal? (list 3 7) (iota 2 3 4))

;;
;; (reverse XS)
;;
($quoted-test-cases (reverse)
  ()        ()
  (1)       (1)
  (1 2)     (2 1)
  (1 2 3)   (3 2 1)
  (1 2 3 4) (4 3 2 1))

;;
;; (filter P? XS)
;;
($quoted-test-cases (filter zero?)
     ()  ()
    (0) (0)
    (1)  ()
  (0 1) (0))

($quoted-test-cases (filter integer?)
  #1=(1 2 3 . #1#)         #1=(1 2 3 . #1#)
  #1=(a b c . #1#)         ()
  #1=(1 a 3 . #1#)         #1=(1 3 . #1#)
  (1 2 a . #1=(b . #1#))   (1 2)
  (f 5 . #1=(6 a b . #1#)) (5 . #1=(6 . #1#)))

;;
;; (partition P? XS)
;;
($quoted-test-cases (partition zero?)
     () ( ()  ())
    (0) ((0)  ())
    (1) ( () (1))
  (0 1) ((0) (1)))

($quoted-test-cases (partition integer?)
  #1=(1 2 3 . #1#)         (#1=(1 2 3 . #1#)   ())
  #1=(a b c . #1#)         (()                 #1=(a b c . #1#))
  #1=(1 a 3 . #1#)         (#1=(1 3 . #1#)     #2=(a . #2#))
  (1 2 a . #1=(b . #1#))   ((1 2)              (a . #2=(b . #2#)))
  (f 5 . #1=(6 a b . #1#)) ((5 . #1=(6 . #1#)) (f . #2=(a b . #2#))))

(summary)

