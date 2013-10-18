;;;
;;; 314-hash-functions.k
;;;
;;; Test of hash tables.
;;;

($define! $equal?
  ($vau xs denv
    ($define! ys
      (map ($lambda (x) (protect-eval x denv)) xs))
    ($if ($and? (apply equal? (cons "return" (map car ys)))
                (apply equal? (map cadr ys)))
      (pass)
      (fail-with-report "hash-tables"
        xs ys (list (car xs) ($quote |...|))))))

;;
;; basic use
;;

($let ((h (make-hash-table)))
  ($equal? #f (hash-table-exists? h 1)
              (hash-table-exists? h #\a)
              (hash-table-exists? h "x"))
  (hash-table-set! h 1 2)
  ($equal? 2 (hash-table-ref h 1))
  ($equal? #t (hash-table-exists? h 1))
  ($equal? #f (hash-table-exists? h #\a) (hash-table-exists? h "x"))
  ($equal? 1 (hash-table-length h))
  (hash-table-set! h #\a 3)
  ($equal? 2 (hash-table-ref h 1))
  ($equal? 3 (hash-table-ref h #\a))
  ($equal? #t (hash-table-exists? h 1) (hash-table-exists? h #\a))
  ($equal? #f (hash-table-exists? h "x"))
  ($equal? 2 (hash-table-length h))
  (hash-table-delete! h 1)
  ($equal? #t (hash-table-exists? h #\a))
  ($equal? #f (hash-table-exists? h 1) (hash-table-exists? h "x"))
  ($equal? 3 (hash-table-ref h #\a))
  ($equal? 1 (hash-table-length h)))

;;
;; basic hashtables compatible with eq? and equal?
;;

($let* ((h1 (make-hash-table eq?))
        (h2 (make-hash-table equal?))
        (k1 ($quote #1=(1 2 . #1#)))
        (k2 (list* 1 2 1 2 k1)))
  ($unless ($and? (equal? k1 k2) (not? (eq? k1 k2))) (error))

  (hash-table-set! h1 k1 1)
  ($equal? #t (hash-table-exists? h1 k1))
  ($equal? #f (hash-table-exists? h1 k2))

  (hash-table-set! h2 k1 1)
  ($equal? #t (hash-table-exists? h2 k1))
  ($equal? #t (hash-table-exists? h2 k2))

  (hash-table-set! h1 k2 2)
  (hash-table-set! h2 k2 2)

  ($equal? 1 (hash-table-ref h1 k1))
  ($equal? 2 (hash-table-ref h1 k2)
             (hash-table-ref h2 k1)
             (hash-table-ref h2 k2))

  ($equal? 2 (hash-table-length h1))
  ($equal? 1 (hash-table-length h2)))

;;
;; growth
;;

($let ((h (make-hash-table)))
  (for-each
    ($lambda (x) (hash-table-set! h x (* 2 x)))
    (iota 500))
  ($equal?
    #t
    (apply hash-table-exists? (cons h (iota 500))))
  ($equal?
    500
    (hash-table-length h))
  ($equal?
    #t
    (apply and?
      (map ($lambda (x) (=? (hash-table-ref h x) (* 2 x)))
           (iota 500)))))

;;
;; copy and merge
;;
($let ((h1 (hash-table 1 2 3 4 5 6))
       (h2 (hash-table 1 5 3 7)))
  ($equal? 3 (hash-table-length (hash-table-merge h1 h2)))
  (hash-table-merge! h2 h1)
  ($equal? 3 (hash-table-length h2))
  ($equal? (hash-table-ref h2 5) 6))

;;
;;
;; user defined hash function and equality
;;

($let* ((hashf ($lambda ((k v)) (hash k)))
        (eqf   ($lambda ((x1 x2) (y1 y2)) (=? x1 y1)))
        (h     (make-hash-table eqf hashf)))
  (hash-table-set! h (list 1 "x") 5)
  (hash-table-set! h (list 2 "y") 6)
  (hash-table-set! h (list 3 "z") 7)
  (hash-table-set! h (list 1 "u") 8)
  ($equal? 8 (hash-table-ref h (list 1 "a")))
  ($equal? 6 (hash-table-ref h (list 2 "b")))
  ($equal? 7 (hash-table-ref h (list 3 "c"))))

(summary)
