;;;
;;; bytevectors.k
;;;
;;; Bytevector features (lisp part).
;;;

($define-ground-lambda! bytevector-copy! (src dst)
  (bytevector-copy-partial! dst 0 (bytevector-length src) src 0))

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
