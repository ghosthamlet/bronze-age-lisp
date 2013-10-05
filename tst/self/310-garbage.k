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

;; end of test
;;
(summary)
