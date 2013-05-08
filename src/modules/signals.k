;;;
;;; signals.k
;;;
;;; Signal-handling features, lisp part.
;;;

($bind-private! signal-setup
  (make-bounded-applicative
    (list 2 2) (list "app_signal_setup.A2") ()))

($bind-private! read-signal
  (make-primitive-operative "op_read_signal"))

($bind-private! user-signal-handlers
  #inert)

($bind-private! signal-names
  ($quote*
    (#:sigint  . 2)
    (#:sigusr1 . 10)
    (#:sigusr2 . 12)
    (#:sigterm . 15)))

($define-private-vau! signal-handler #ignore #ignore
  ($let1 v (read-signal)
    ($cond
      ((eof-object? v)
        #inert)
      ((fixint? v)
        (apply (vector-ref user-signal-handlers v) (list v))
        (signal-handler))
      ((ignore? v)
        (error "Signal ring overflow."))
      (#t
        (error "Internal error in signal handling." v)))))

($define-private-lambda! signal-number (s)
  ($if ($and? (integer? s) (<=? 1 s 65))
    s
    ($let1 a (assoc s signal-names)
      ($if (pair? a)
        (cdr a)
        (error "Invalid signal number. " s)))))

($define-private-lambda! signal (s h)
  ($when (inert? user-signal-handlers)
    ($set! private-environment user-signal-handlers
      (make-vector 65 #:default)))
  ($define! v (signal-number s))
  ($define! old-h (vector-ref user-signal-handlers v))
  (signal-setup
    v
    ($cond
      (($and? (applicative? h) (operative? (unwrap h)))
        (vector-set! user-signal-handlers v h)
        #t)
      ((eq? h #:default)
        (vector-set! user-signal-handlers v h)
        #f)
      ((eq? h #:ignore)
        (vector-set! user-signal-handlers v h)
        #ignore)
      (#t
        (error "Invalid signal handler." h))))
  old-h)

($define-ground-lambda! with-signal-handler ((s h) f)
  ($define! old-h (signal s h))
  (guard-dynamic-extent
    (list (list root-continuation
                ($lambda (obj . #ignore)
                  (signal s h)
                  obj)))
    ($lambda () (apply f ()))
    (list (list root-continuation
                ($lambda (obj . #ignore)
                  (signal s old-h)
                  obj))))
  (signal s old-h))

