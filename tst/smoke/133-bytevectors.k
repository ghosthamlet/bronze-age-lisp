;; basic test of bytevectors
(list
  (bytevector? (make-bytevector 0))
  (bytevector? (make-bytevector 1))
  (bytevector? (make-bytevector 2))
  (bytevector-length (make-bytevector 0))
  (bytevector-length (make-bytevector 1))
  (bytevector-length (make-bytevector 2))
  (bytevector-u8-ref (make-bytevector 1 42) 0)
  ($let ((v (make-bytevector 3 4)))
     (bytevector-u8-set! v 1 5)
     (list
       (bytevector-u8-ref v 0)
       (bytevector-u8-ref v 1)
       (bytevector-u8-ref v 2))))
