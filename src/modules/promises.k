;;;
;;; promises.k
;;;
;;; Promises (lazy evaluation) module, lisp part.
;;;


($bind-private! promise-ref
  (make-bounded-applicative
    (list 1 1) (list "app_promise_ref.A1") ()))

($bind-private! promise-set!
  (make-bounded-applicative
    (list 2 2) (list "app_promise_setB.A2") ()))

($define-ground-lambda! force (x)
  ($if (promise? x) (force-promise x) x))

($defun-privates!
  (force-promise (x)
    ($let (((object . env) (promise-ref x)))
      ($if (environment? env)
        (handle-promise-result x (eval object env))
        object)))
  (handle-promise-result (x y)
    ($let1 node (promise-ref x)
      ($cond ((null? (cdr node))    ; check for earlier result
                (car node))
             ((not? (promise? y))
                (set-car! node y)        ;
                (set-cdr! node ())       ; memoize
                y)
             (#t
                (promise-set! x (promise-ref y))
                (force-promise x))))))
