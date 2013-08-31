;;;
;;; processes.k
;;;
;;; Linux process handling (lisp part)
;;;

;; bind the symbols in the private environment
;; in order to emit assembler constants

(for-each
  ($lambda (s)
    (bind-ground! (string->symbol (keyword->string s))
                  s))
  ($quote*
    #:inherit #:nohang #:exited #:waiting #:signalled))

($define-ground-lambda! system (cmd)
 ;; TODO: also block SIGCHLD
  (with-signal-handler (list #:sigint #:ignore)
    ($lambda ()
      (with-signal-handler (list #:sigquit #:ignore)
        ($lambda ()
          (cdr
            (waitpid
              (fork
                ($lambda ()
                  (execve "/bin/sh"
                          (list "/bin/sh" "-c" cmd)))
                error-continuation))))))))
