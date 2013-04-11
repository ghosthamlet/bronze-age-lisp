;;;
;;; ports.k
;;;
;;; High-level port features.
;;;

($define-private-lambda! ignore-errors-guard (x d)
  (d))

($define-ground-lambda! close-port-ignore-errors (p)
  (guard-dynamic-extent
    ()
    ($lambda () (close-port p))
    (list (list error-continuation ignore-errors-guard)))
  #inert)

($define-ground-lambda! call-with-port (port proc)
  ($let*
    ((result
      (guard-dynamic-extent
        ()
        ($lambda () (proc port))
        (list (list error-continuation
                    ($lambda (x d)
                      (close-port-ignore-errors port)
                      x))))))
    (close-port port)
    result))

($define-ground-lambda! call-with-input-file (file proc)
  (call-with-port (open-input-file file) proc))

($define-ground-lambda! call-with-output-file (file proc)
  (call-with-port (open-output-file file) proc))

;;
;; management of dynamic port variables
;;

($define-ground-lambda! get-current-input-port () stdin)
($define-ground-lambda! get-current-output-port () stdin)
($define-ground-lambda! get-current-error-port () stdin)

($define-private-vau! $with-dynamic-port (symbol new proc) denv
  ($define! new (eval new denv))
  ($define! proc (eval proc denv))
  ($define! old (eval symbol private-environment))
  (set! private-environment symbol new)
  ($define! result
    (guard-dynamic-extent
      (list
        (list root-continuation
              ($lambda (x #ignore)
                (set! private-environment symbol old)
                x)))
        proc
        (list
          (list root-continuation
                ($lambda (x #ignore)
                  (set! private-environment symbol new)
                   x)))))
  (set! private-environment symbol old)
  result)

($define-ground-lambda! with-input-from-port (port proc)
  ($with-dynamic-port stdin port proc))

($define-ground-lambda! with-output-to-port (port proc)
  ($with-dynamic-port stdout port proc))

($define-ground-lambda! with-input-from-file (file proc)
  (call-with-input-file file
    ($lambda (port) (with-input-from-port port proc))))

($define-ground-lambda! with-output-to-file (file proc)
  (call-with-output-file file
    ($lambda (port) (with-output-to-port port proc))))

($define-ground-lambda! with-input-from-string (s proc)
  (with-input-from-port (open-input-string s) proc))

($define-ground-lambda! with-output-to-string (proc)
  ($let* ((port (open-output-string)))
    (with-output-to-port port proc)
    (get-output-string port)))
