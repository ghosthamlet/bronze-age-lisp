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

(summary)
