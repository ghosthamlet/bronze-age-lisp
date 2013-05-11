;;
;; 03-iterative-div2.k
;;
;; Halving unary number representation. The result
;; values are the same as in 02-recursive-div2.k
;;

;; This is as imperative as possible using only
;; built-in klisp functionality.
;;
($define! iterative-div2
  ($lambda (l)
    ($define! a ())
    #1=($unless (null? l)
         ($define! a (cons (car l) a))
         ($define! l (cddr l))
         #1#)
    a))

;; write out few results, just to check

(write
  (list (length (iterative-div2 (make-list 20)))
        (length (iterative-div2 (make-list 152)))))
(newline)

;; run the test

($define! test
  ($lambda (l n s)
    ($if (<? 0 n)
      ($sequence
        (iterative-div2 l)
        (iterative-div2 l)
        (test l
              (- n 1)
              (+ s (length (iterative-div2 l)))))
      (write s))))

(test (make-list 500) 300 0)
(newline)
