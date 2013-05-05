;;;
;;; system.k
;;;

;;
;; Slot for lazily initialized list of environment variables
;; and the initialization function.
;;
($bind-private! environ #inert)
($bind-private! init-environ (make-primitive-operative "op_init_environ"))

;;
;; ground bindings
;;
($define-ground-lambda! defined-environment-variable? (var)
  (init-environ)
  (pair? (assoc var environ)))

($define-ground-lambda! get-environment-variable (var)
  (init-environ)
  (cdr (assoc var environ)))

($define-ground-lambda! get-environment-variables ()
  (init-environ)
  environ)

;;
;; performance statistics
;;
($bind-private! perf-time
  (make-bounded-applicative
    (list 1 1) (list "app_perf_time.A1") ()))

($define-ground-lambda! get-performance-statistics ()
  (list
    (cons #:perf-time
      (map
        ($lambda ((name . index))
          (cons name (perf-time index)))
        perf-time-sections))))
