;;;
;;; sorting.k
;;;
;;; Merge sort on lists. API based on SRFI-95.
;;;

($define-private-lambda! merge-aux (a b lt?)
  ($cond
    ((null? a)               b)
    ((null? b)               a)
    ((lt? (car b) (car a))   (cons (car b) (merge-aux a (cdr b) lt?)))
    (#t                      (cons (car a) (merge-aux (cdr a) b lt?)))))

($define-private-lambda! sort-prefix (h n lt?)
  ($cond
    ((zero? n) ())
    ((=? n 1)  (list (car h)))
    (#t        ($let1 k (arithmetic-shift n -1)
                 (merge-aux (sort-prefix h k lt?)
                            (sort-prefix (list-tail h k) (- n k) lt?)
                            lt?)))))

($define-private-lambda! sort-predicate (rest)
  ($match rest
    ((less?)
      ;; N.B. less? will not be called in descendand of the private
      ;; environment. Using apply would break interpreter optimizations.
      (eval (list $lambda ($quote* x y) (list* less? ($quote* x y)))
            (make-environment)))
    ((less? key)
      (eval (list $lambda ($quote* x y)
                  (list less?
                        (list key ($quote x))
                        (list key ($quote y))))
            (make-environment)))
    (#ignore
      ($error1 sort "Invalid argument structure." rest))))

($define-ground-lambda! sorted? (a . rest)
  ($let* ((lt? (sort-predicate rest))
          (ok? ($lambda ((x y)) (not? (lt? y x)))))
    (apply and? (map ok? (list-neighbors a)))))

($define-ground-lambda! merge (a b . rest)
  ($if (finite-list? a b)
    (merge-aux a b (sort-predicate rest))
    ($error merge "Unable to merge cyclic lists." a b)))

($define-ground-lambda! sort (a . rest)
  ($let1 n (length a)
    ($if (finite? n)
      (sort-prefix a n (sort-predicate rest))
      ($error sort "Unable to sort cyclic list." a))))
