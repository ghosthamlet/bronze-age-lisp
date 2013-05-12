;;
;; 08-binomial.k
;;
;; Naive computation of binomial coefficients.
;; Benchmark for bigint operations.
;;

($define! factorial
  ($lambda (n)
    ($if (<=? n 1)
      1
      (* n (factorial (- n 1))))))

($define! binomial-coefficient
  ($lambda (n k)
    (div (factorial n)
         (* (factorial k) (factorial (- n k))))))

($define! test
  ($lambda ()
    (list (binomial-coefficient 34 31)
          (binomial-coefficient 456 123)
          (binomial-coefficient 5678 1234))))

(write (test))
