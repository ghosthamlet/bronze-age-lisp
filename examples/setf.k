;;;
;;; setf.k
;;;
;;; A combiner inspired by Common Lisp SETF macro.
;;;
;;; In Common Lisp, SETF is a macro and (SETF <place> <value>) examines
;;; the syntactic structure of <place> and derives the name of the
;;; appropriate setter functions from it. In Scheme (SRFI-17), generalized
;;; (set! ...) is also a macro, but the setter function object is stored
;;; as a property of the getter.
;;;
;;; Both CL approach could work with FEXPRs as well, but deconstructing
;;; syntax is not much in the spirit of the Kernel Language. Here we
;;; use different hack.
;;;
;;; In Kernel Language, continuations are first-class objects. Combiners
;;; can, to some extent, examine their dynamic extend and detect where
;;; their results end up in. If a combiner detects that its result will
;;; end in the the <place> position of
;;;
;;;    ($setf! <place> <value>)
;;;
;;; it returns a new combiner which $setf! uses to store the value.

;;
;; $provide-safe! is like $provide!, but evaluates its body in
;; an initially standard environment. Here, $provide-safe! ensures
;; that car and cdr used in definition of $setf! are the standard
;; combiners, and not the combiners generalized by $setf!.
;;
($define! $provide-safe!
  ($vau (symbols . body) denv
    ($define! e (make-kernel-standard-environment))
    (eval (cons $sequence body) e)
    (eval (list* $import! e symbols) denv)))

;;
;; Define SETF functionality.
;;
;;  ($setf! PLACE NEW-VALUE) => #inert
;;
;;     Analogous to Common Lisp SETF.
;;
;;  (make-setf-aplicative GETTER SETTER) => applicative
;;
;;    where (GETTER ARGS...) => current value
;;      and (SETTER ARGS... NEW-VALUE) =>
;;
;;     Analogous to Common Lisp DEFSETF.
;;
;;  ($get-and-setf PLACE) => (SPECIALIZED-GETTER SPECIALIZED-SETTER)
;;
;;    where (SPECIALIZED-GETTER) => value of PLACE
;;          (SPECIALIZED-SETTER X) => #inert, store X in PLACE
;;
($provide-safe! ($setf! $get-and-setf make-setf-applicative)

  ($define! (bind-setf-context access-setf-context)
    (make-keyed-dynamic-variable))

  ($define! guard
    ($lambda (#ignore divert)
      (apply-continuation divert ())))

  ($define! safe-access-setf-context
    ($let ((guards (list (list error-continuation
                               ($lambda (#ignore divert) (divert))))))
      ($lambda ()
        (guard-dynamic-extent () access-setf-context guards))))

  ($define! $setf!
    ($vau (place value) env
      (apply
        (bind-setf-context (list #:set)
          ($lambda ()
            ($let/cc k
              (set-cdr! (access-setf-context) k)
              (eval place env))))
        (list (eval value env))
        env)))

  ($define! $get-and-setf
    ($vau (place) env
      (bind-setf-context (list #:get+set)
        ($lambda ()
          ($let/cc k
            (set-cdr! (access-setf-context) k)
            (eval place env))))))

  ($define! make-setf-applicative
    ($lambda (get set)
      ($lambda args
        ($let/cc k
          ($let ((c (safe-access-setf-context)))
            ($cond
              (($or? (null? c)               ; dyn. variable not bound
                     (not? (eq? (cdr c) k))) ; dyn. var. bound to "other" continuation
                ;; getter mode
                (apply get args))
              ((eq? (car c) #:set)
                ;; setter mode
                ($lambda x (apply set (append args x))))
              ((eq? (car c) #:get+set)
                ;; getter and setter
                (list ($lambda () (apply get args))
                      ($lambda x (apply set (append args x))))))))))))

;;
;; Add $setf! support to car and cdr.
;;
($define! (car cdr)
  ($let-safe ((make-setf-applicative make-setf-applicative))
    (list (make-setf-applicative car set-car!)
          (make-setf-applicative cdr set-cdr!))))

;;
;; The following definitions will make $setf! work with cadr and cdar
;; too. Note that the last car or cdr is evaluated in the tail position.
;;
($define! cadr ($lambda (x) (car (cdr x))))
($define! cdar ($lambda (x) (cdr (car x))))

;;
;; (test-1) => (4 5 3)
;;
($define! test-1
  ($lambda ()
    ($define! ls (list 1 2 3))
    ($setf! (car ls) 4)
    ($setf! (cadr ls) 5)
    ls))

;;
;; Define generalized swap.
;;
($define! $swap!
  ($vau (x y) env
    ($let* (((get-x set-x) (eval (list $get-and-setf x) env))
            ((get-y set-y) (eval (list $get-and-setf y) env))
            (x-value       (get-x))
            (y-value       (get-y)))
      (set-x y-value)
      (set-y x-value))))

($define! list-ref
  ($lambda (x n)
    ($if (>? n 0)
      (list-ref (cdr x) (- n 1))
      (car x))))

;;
;; (test-2) => (1 4 3 2)
;;
($define! test-2
  ($lambda ()
    ($define! ls (list 1 2 3 4))
    ($swap! (list-ref ls 1) (list-ref ls 3))
    ls))

;;
;; Define records on top of vectors.
;;

($define! vref
  (make-setf-applicative vector-ref vector-set!))

($define! $define-record!
  ($vau (struct-name . fields) user-env
    ($define! stem
      (symbol->string struct-name))
    ($define! $def!
      ($vau (name . args-body) env
        (eval (list $define!
                    (string->symbol (apply (wrap string-append) name env))
                    (eval (cons $lambda args-body) env))
              user-env)))

    ($def! (stem "?") (x)
      ($and? (vector? x) (eq? (vector-ref x 0) struct-name)))
    ($def! ("make-" stem) xs
      (list->vector (cons struct-name xs)))

    ($define! define-field-access
      ($lambda (index fields)
        ($when (pair? fields)
          ($def! (stem "-" (symbol->string (car fields))) (x)
            ($if ($and? (vector? x) (eq? (vector-ref x 0) struct-name))
              (vref x index)
              (error "Invalid argument" struct-name (car fields) x)))
          (define-field-access (+ index 1) (cdr fields)))))

    (define-field-access 1 fields)))

;;
;; (test-3) => (#(point 3 2) #t 3 2)
;;

($define! test-3
  ($lambda ()
    ($define-record! point x y)
    ($define! p (make-point 1 2))
    ($setf! (point-x p) 3)
    (list p (point? p) (point-x p) (point-y p))))
