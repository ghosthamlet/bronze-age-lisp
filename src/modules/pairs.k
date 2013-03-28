;;;
;;; pairs.k
;;;

(for-each
  ($lambda (sym)
    (bind-ground! sym
      (make-bounded-applicative
        (list 1 1)
        (list (string-append* "app_cXr." sym))
        (list sym))))
  ($quote*
    car cdr
    caar cadr cdar cddr))

($bind-ground! list*
  (make-rom-object
    (applicative-header* 6)
    (make-nonlisp-value "app_listX")
    (make-rom-object
      (operative-header* 2)
      (make-nonlisp-value "app_listX.operate"))
    (make-nonlisp-value "app_listX.A1")
    (make-nonlisp-value "app_listX.A2")
    (make-nonlisp-value "app_listX.A3")))
