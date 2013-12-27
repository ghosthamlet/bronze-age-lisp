;;;
;;; 306-bigint-arithmetic.k
;;;

($define! $eq
  ($vau (e1 e2) denv
    ($let
      ((r1 (protect-eval e1 (make-kernel-standard-environment)))
       (r2 (protect-eval e2 (make-kernel-standard-environment))))
      ($if (equal? r1 r2)
        (pass)
        (fail-with-report
          "bigint"
          e1
          r1 r2)))))

($eq (- 2882400001 2684354560) 198045441)
($eq (+ 312494775164 3199745327106) 3512240102270)
($eq (* 269064677 173053677) 46562631705667329)

($eq (div -3213312123 -12123) 265060)
($eq (mod -3213312123 -12123) 10257)
($eq (div-and-mod -3213312123 -12123) (list 265060 10257))

($eq (div0-and-mod0 22993238902637627876 30586303013202419669)
     (list 1 -7593064110564791793))

($eq (expt 2 42) 4398046511104)
($eq (expt -23 45) -18956258430116202791319715713277227626159289499745290235663543)

($eq ($letrec ((fac ($lambda (n) ($if (positive? n) (* n (fac (- n 1))) 1))))
       (div
         (apply + (map ($lambda (k) (div (expt 10 100) (fac k))) (iota 50)))
         (expt 10 50)))
     271828182845904523536028747135266249775724709369995)

(summary)
