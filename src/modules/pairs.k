;;;
;;; pairs.k
;;;

;; Define selectors car, cdr, ..., cddr.
;;
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

;; Define selectors caaar, caadr, ..., cdddr as interpreted
;; applicatives.
;;
($provide! ()

  ($define! make-ad-list
    ($lambda (n)
      ($if (=? n 0)
        (list ())
        ($let ((tails (make-ad-list (- n 1))))
          (append
            (map ($lambda (x) (cons #\a x)) tails)
            (map ($lambda (x) (cons #\d x)) tails))))))

  ($define! leaf-symbol
    ($quote x))

  ($define! ptree
    ($lambda (ads)
      ($cond
        ((null? ads) leaf-symbol)
        ((eq? (car ads) #\a) (cons (ptree (cdr ads)) #ignore))
        ((eq? (car ads) #\d) (cons #ignore (ptree (cdr ads)))))))

  (for-each
    ($lambda (ads)
      ($define! name
        (string->symbol
          (string-append "c" (list->string (reverse ads)) "r")))
      (bind-ground! name
        (make-builtin-lambda
          name
          (list (ptree ads))
          (list leaf-symbol))))
    (append (make-ad-list 3) (make-ad-list 4))))

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
