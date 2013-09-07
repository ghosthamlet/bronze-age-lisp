;; basic test of keyword features
(list
  (list (keyword? #:a) (keyword? "a") (keyword? ()))
  (list (keyword->string #:kwd) (keyword->symbol #:kwd))
  (list (symbol->keyword ((unwrap list*) a)) (string->keyword "b"))
  ($let ((x (string->keyword "abc"))
         (y (string->keyword "def"))
         (z (string->keyword (string-append "ab" "c"))))
    (list (eq? x y) (equal? x y) (eq? x z) (equal? x z))))

