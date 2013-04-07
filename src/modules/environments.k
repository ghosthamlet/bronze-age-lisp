;;;
;;; environments.k
;;;
;;; Implementation of environment features (lisp part).
;;;
;;; The definitions were copied from Kernel Report.
;;;
;;; TODO: Efficient implementation for common cases.
;;;

($define-ground-vau! $letrec* (bindings . body) env
  (eval ($if (null? bindings)
             (list* $letrec bindings body)
             (list $letrec
                   (list (car bindings))
                   (list* $letrec* (cdr bindings) body)))
         env))
