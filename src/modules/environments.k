;;;
;;; environments.k
;;;
;;; Implementation of environment features (lisp part).
;;;
;;; The definitions were copied from Kernel Report.
;;;
;;; TODO: Efficient implementation for common cases.
;;;

($define-ground-vau! $let (bindings . body) env
  (eval (cons (list* $lambda (map car bindings) body)
              (map cadr bindings))
        env))
