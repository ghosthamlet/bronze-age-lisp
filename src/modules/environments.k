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

($define-ground-vau! $remote-eval (o e) d
  (eval o (eval e d)))

($define-ground-vau! $bindings->environment bindings denv
  (eval (list $let-redirect
              (make-environment)
              bindings
              (list get-current-environment))
        denv))

($define-ground-vau! $provide! (symbols . body) env
  (eval (list $define! symbols
          (list $let ()
            (list* $sequence body)
            (list* list symbols)))
        env))

($define-ground-vau! $import! (exp . symbols) env
  (eval (list $set!
              env
              symbols
              (cons list symbols))
        (eval exp env)))

($define-ground-lambda! eval-string (str env)
  ($let* ((p (open-input-string str))
          (x (read p)))
    ($cond
      ((eof-object? x)
        ($error1 eval-string "Too few values in string." str))
      ((not? (eof-object? (read p)))
        ($error1 eval-string "Too many values in string." str))
      (#t
        (eval x env)))))
