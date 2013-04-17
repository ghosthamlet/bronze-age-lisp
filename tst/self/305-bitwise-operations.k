;;;
;;; 305-bitwise-operations.k
;;;
;;; Test bitwise operations on fixints and bigints.
;;;

($define! $eq
  ($vau (e1 e2) denv
    ($let
      ((r1 (protect-eval e1 (make-kernel-standard-environment)))
       (r2 (protect-eval e2 (make-kernel-standard-environment))))
      ($if (equal? r1 r2)
        (pass)
        (fail-with-report
          "bitwise"
          e1
          r1 r2)))))

;; integer-length
;;
($eq (integer-length (* 256 256 256 256)) 33)
($eq (map integer-length (list 0 1 -1 7 -7 8 -8))  ; examples
                         (list 0 1  0 3  3 4  3))  ; from SRFI-33

(summary)
