;;;
;;; 310-garbage.k
;;;
;;; Test garbage collector.
;;;

($define! run-test
  ($lambda (exprs)
    (collect-garbage)
    ($let
      ((a (protect-eval (cons $sequence exprs)
                        (make-kernel-standard-environment)))
       (b (list "return" #inert)))
      (collect-garbage)
      ($if (equal? a b)
        (pass)
        (fail-with-report
          "garbage"
          exprs
          a b)))))

($define! $rep
  ($vau (n . body) denv
    ($define! i ($quote I))
    ($define! f ($quote F))
    (run-test
      (list
        (list $define! f
          ;; construct function body directly in order to avoid
          ;; allocation in test driver as much as possible
          (list $lambda (list i)
            (list $when (list positive? i)
              (cons $sequence body)
              (list f (list - i 1)))))
        (list f n)))))

;; Create garbage on the lisp heap.
;;
($rep 100000 (cons 1 2))

;; (get-output-string) creates both lisp and blob garbage
;;
($rep 100000 (open-output-string))

;; create combiners on the heap
;;
($rep 100000
  (map ($lambda #ignore ($quote* 1)) ($quote* 2)))

;; allocate lot of bigints
;;
($let ()
  ($define! m 200)
  ($define! loop
    ($lambda (n x y)
      ($cond
        ((<=? n 0)
          x)
        ((<? (integer-length x) m)
          (loop (- n 1)
                (arithmetic-shift (bitwise-xor x (hash n)) 50)
                y))
        ((<? (integer-length y) m)
          (loop (- n 1)
                x
                (arithmetic-shift (bitwise-xor y (hash n)) 50)))
        (#t
          (loop (- n 1)
                (mod (bitwise-xor x (hash n)) (+ 17 (bitwise-xor y (hash n))))
                (+ 3 (arithmetic-shift y -1)))))))
  (apply (wrap $rep) (list 10 (list loop 100000 0 0))))

;; end of test
;;
(summary)
