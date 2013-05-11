;;
;; 02-recursive-div2.k
;;
;; Halving unary number representation. Adapted from [1], page 186.
;;
;;  [1] R. Gabriel: Performance and evaluation of Lisp systems.
;;      http://www.dreamsongs.com/NewFiles/Timrep.pdf.
;;
;;
($define! recursive-div2
  ($lambda (l)
    ($cond
      ((null? l) ())
      (#t        (cons (car l)
                       (recursive-div2 (cddr l)))))))

;; write out few results, just to check

(write
  (list (length (recursive-div2 (make-list 20)))
        (length (recursive-div2 (make-list 152)))))
(newline)

;; run the test

($define! test
  ($lambda (l n s)
    ($if (<? 0 n)
      ($sequence
        (recursive-div2 l)
        (recursive-div2 l)
        (test l
              (- n 1)
              (+ s (length (recursive-div2 l)))))
      (write s))))

(test (make-list 500) 300 0)
(newline)
