;;
;; 07-promises.k
;;
;; Benchmark adapted from the Kernel Report,
;; section 9.1.
;;
($define! stream-filter
   ($lambda (p? s)
      ($lazy
         ($let ((v (force s)))
            ($if (null? v)
                 v
                 ($let ((s (stream-filter p? (cdr v))))
                    ($if (p? (car v))
                         (cons (car v) s)
                         s)))))))
($define! from
   ($lambda (n)
      ($lazy (cons n (from (+ n 1))))))

(write
  (force (stream-filter ($lambda (n) (=? n 100000))
                        (from 0))))
