;;;
;;; assertions.k
;;;
;;; Run-time assertion checking.
;;;

($define-private-lambda! es-symbols-aux (x s a)
  ($cond
    (($and? (symbol? x) (not? (memq? x a)))
      (cons x a))
    ((pair? x)
      ($cond
        ((not? ((car s) x))
          #1=(es-symbols-aux (cdr x) s (es-symbols-aux (car x) s a)))
        ((memq? x (cdr s))
          a)
        (#t
          (set-cdr! s (cons x (cdr s)))
          #1#)))
    (#t
      a)))

($define-ground-lambda! es-symbols (p)
  (es-symbols-aux p (list (shared-structure-indicator p)) ()))

;;
;; $assert
;;

($bind-ground! false-guards ())

(init-forms-add!
  ($quote
    ($define! false-guards
      (list (list error-continuation
                  ($lambda (#ignore divert) (apply divert #f)))))))

($define-ground-vau! $assert (x . rest) env
  ($unless (eq? #t (guard-dynamic-extent ()
                                         ($lambda () (eval x env))
                                         false-guards))
    ($define! p (get-current-output-port))
    (format p
            ($if (color-port? p)
                 "~% \x1B;[31;1m** Assertion failed **\x1B;[m~%  ~w~%"
                 "~% ** Assertion failed **~%  ~w~%")
            x)
    ($unless (null? rest)
      (format p "  ~a~%" rest))
    (for-each
      ($lambda (v)
        ($cond
          (($and? (binds? env v)
                  (not? ($and? (binds? private-environment v)
                               (equal? (eval v private-environment)
                                       (eval v env)))))
            (format p "    ~w = ~w~%" v (eval var env)))
          ((not? (binds? env v))
            (format p "    ~w is not bound~%" v))))
      (es-symbols (cons x rest)))
    ($error1 $assert "Assertion failed." (cons x rest))))
