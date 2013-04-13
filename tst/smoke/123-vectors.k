;; basic test of vectors
(list
  (vector? (make-vector 0))
  (vector? (make-vector 1))
  (vector? (make-vector 2))
  (vector-length (make-vector 0))
  (vector-length (make-vector 1))
  (vector-length (make-vector 2))
  (vector-ref (make-vector 1 #t) 0)
  ($let ((v (make-vector 3 4)))
     (vector-set! v 1 5)
     (list
       (vector-ref v 0)
       (vector-ref v 1)
       (vector-ref v 2))))
