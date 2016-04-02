;;;
;;; bytevectors.k
;;;
;;; Bytevector features (lisp part).
;;;

($define-ground-lambda! bytevector-copy! (src dst)
  (bytevector-copy-partial! src 0 (bytevector-length src) dst 0))

($define-ground-lambda! utf8->string (b)
  ($define! p (open-input-string b))
  ($define! q (open-output-string))
  #1=($sequence
       ;; read-char checks well-formedness of the UTF-8 stream
       ($define! c (read-char p))
       ($unless (eof-object? c)
         (write-char c q)
         #1#))
  (get-output-string q))

($define-ground-lambda! bytevector->vector (b)
  ($define! v (make-vector (bytevector-length b)))
  ($dotimes (i (bytevector-length b) v)
    (vector-set! v i (bytevector-u8-ref b i))))

($define-ground-lambda! vector->bytevector (v)
  ($define! b (make-bytevector (vector-length v)))
  ($dotimes (i (vector-length v) b)
    (bytevector-u8-set! b i (vector-ref v i))))
