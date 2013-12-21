;;;
;;; libraries.k
;;;
;;; Klisp-compatible library system, lisp part.
;;;

;; low-level interface
;;
($bind-private! library-table ())

($bind-private! make-library-object
  (make-bounded-applicative
    (list 1 1) (list "app_make_library_object.A1") ()))

($define-ground-lambda! make-library pairs
  ($let ((e (make-environment)))
    (for-each
      ($lambda (p)
        ($unless ($and? (pair? p) (symbol? (car p)))
          (error "Invalid argument." pairs))
        ($when ((wrap $binds?) e (car p))
          (error "Duplicate library export." (car p) pairs))
        (set! e (car p) (cdr p)))
      pairs)
    (make-library-object e)))

($define-ground-vau! $registered-library? (name) #ignore
  (pair? (assoc name library-table)))

($define-ground-vau! $register-library! (name library) denv
  ($unless ($and? (finite-list? name)
                  (apply library-name-component? name))
    (error "Invalid library name." name))
  ($define! name (copy-es-immutable name))
  ($unless (null? (assoc name library-table))
    (error "Library already registered." name))
  ($define! library (eval library denv))
  ($unless (library? library)
    (error "Invalid argument." library))
  ($set! private-environment library-table
    (cons (cons name library) library-table)))

($define-ground-vau! $unregister-library! (name) #ignore
  ($unless ($and? (finite-list? name)
                  (apply library-name-component? name))
    (error "Invalid library name." name))
  ($if (pair? (assoc name library-table)
    ($set! private-environment library-table
      (filter ($lambda (elt) (not? (equal? name (car elt))))
        library-table))
    (error "Library not registered." name))))

($define-ground-vau! $get-registered-library (name) #ignore
  ($unless ($and? (finite-list? name)
                  (apply library-name-component? name))
    (error "Invalid library name." name))
  ($let ((elt (assoc name library-table)))
    ($if (pair? elt)
      (cdr elt)
    (error "Library not registered." name))))

;; high-level interface
;;
($define-ground-vau! $provide-library! (name exports . body) denv
  ($unless ($and? (finite-list? exports)
                  (not? (null? exports))
                  (eq? (car exports) #:export))
    (error "Invalid library export list." exports))
  ($let ((e (make-environment denv)))
    (eval-sequence body e)
    ((wrap $register-library!)
      name
      (apply make-library
        (map
          ($lambda (x)
            ($cond
              ((symbol? x)
                (cons x (eval x e)))
              (($and? (=? 3 (length x))
                      (eq? (car x) #:rename)
                      (apply symbol? (cdr x)))
                (cons (caddr x) (eval (cadr x) e)))
              (#t
                (error "Invalid export specification."
                  x (list name exports |...|)))))
          (cdr exports))))))

($define-ground-vau! $import-library! imports denv
  (for-each
    ($lambda (i)
      (for-each
        ($lambda ((k . v)) (set! denv k v))
        (import-library-bindings i)))
    imports))

($bind-private! import-library-bindings #inert)
(init-forms-add!
  ($quote*
    $define!
    import-library-bindings
    ($case-lambda
      (((#:only spec . symbols))
        ($let ((b (import-library-bindings spec)))
          (map ($lambda (s) (assoc s b))
            symbols)))
      (((#:except spec . symbols))
        (filter
          ($lambda ((k . #ignore)) (not? (member? k symbols)))
          (import-library-bindings spec)))
      (((#:prefix spec p))
        ($let ((p (symbol->string p)))
        (map
          ($lambda (k . v)
            (cons (string->symbol
                    (string-append p (symbol->string k)))
                  v))
          (import-library-bindings spec))))
      (((#:rename spec pairs))
        (map
          ($lambda kv
            ($let1 r (assoc (car kv) pairs)
              ($if (pair? r)
                (cons (cadr r) (cdr v))
                kv)))
          (import-library-bindings spec)))
      ((name)
        ($let* ((lib ((wrap $get-registered-library) name))
                (env (get-library-environment lib)))
          (map
            ($lambda (s) (cons s (eval s env)))
            (get-library-export-list lib)))))))

