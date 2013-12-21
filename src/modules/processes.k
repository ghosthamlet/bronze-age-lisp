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
    #:inherit #:nohang #:exited #:waiting #:signalled #:no-cloexec))

($define-private-lambda! with-signals-for-subprocess (f)
  (with-signal-handler (list #:sigint #:ignore)
    ($lambda ()
      (with-signal-handler (list #:sigquit #:ignore)
        f))))

($define-ground-lambda! system (cmd)
 ;; TODO: also block SIGCHLD
  (with-signals-for-subprocess
    ($lambda ()
      (cdr
        (waitpid
          (fork
            ($lambda ()
              (execve "/bin/sh" (list "/bin/sh" "-c" cmd)))
            error-continuation))))))

($defun-privates!
  (redirect-for-parent (e item)
    ($define! (pt pp ps cp . #ignore) item)
    (close-port-ignore-errors cp)
    ($define! pp (pt pp))
    (set! e ps pp)
    (set-car! (list-tail item 1) pp)
    (set-car! (list-tail item 3) #inert))
  (redirect-for-child ((pt pp ps cp . cfds))
    (close-port-ignore-errors pp)
    (for-each ($lambda (f) (dup2 cp f)) cfds)
    (close-port-ignore-errors cp))
  (redirect-cleanup (item)
    ($define! (pt pp ps cp . #ignore) item)
    (close-port-ignore-errors pp)
    (close-port-ignore-errors cp)
    (set-car! (list-tail item 1) #inert)
    (set-car! (list-tail item 3) #inert))
  (redirect-close (p items)
    ($define! itms
      (filter ($lambda ((pt pp . #ignore)) (eq? p pp)) items))
    ($if (=? 1 (length itms))
      (redirect-cleanup (car itms))
      (error "$with-subshell/subprocess:close-pipe: not an open pipe"
        p)))
  (redirect-env ()
    ($bindings->environment
      (redirections  ())
      (stdin         (redirect-prepare open-utf-encoder w s r 0))
      (binary-stdin  (redirect-prepare open-buffered-binary-output-port w s r 0))
      (raw-stdin     (redirect-prepare list*            w s r 0))
      (stdout        (redirect-prepare open-utf-decoder r s w 1))
      (binary-stdout (redirect-prepare open-buffered-binary-port r s w 1))
      (raw-stdout    (redirect-prepare list*            r s w 1))
      (stderr        (redirect-prepare open-utf-decoder r s w 2))
      (stdout+stderr (redirect-prepare open-utf-decoder r s w 1 2))))
  (redirect-launch (exec opts body denv)
    ($define! re (redirect-env))
    ($define! cleanup
      ($lambda (err . #ignore)
        (for-each redirect-cleanup
          ($remote-eval redirections re))
        ($when ($binds? re pid)
          (waitpid ($remote-eval pid re)))
        err))
    (guard-dynamic-extent
      ()
      ($lambda ()
        (eval-sequence opts re)
        ($define! rs ($remote-eval redirections re))
        ($set! re pid
          (fork
            ($lambda () (for-each redirect-for-child rs) (exec))
            error-continuation))
        ($define! ue (make-environment denv))
        ($set! ue close-pipe ($lambda (p) (redirect-close p rs)))
        (for-each ($lambda (i) (redirect-for-parent ue i)) rs)
        ($define! r (eval-sequence body ue))
        (for-each redirect-cleanup rs)
        (list (cdr (waitpid ($remote-eval pid re))) r))
      (list (list error-continuation cleanup)))))

($define-private-vau! redirect-prepare lst #ignore
  ($vau (s) e
    ($set! e redirections
      (cons
        ($let (((r w) (open-raw-pipe #:no-cloexec)))
          (eval (cons list lst) (get-current-environment)))
        ($remote-eval redirections e)))))

($define-ground-vau! $with-subprocess (args opts . body) denv
  ($define! args (eval (cons list args) denv))
  (with-signals-for-subprocess
    ($lambda ()
      (redirect-launch
        ($lambda () (apply execve args))
        opts
        body
        denv))))

($define-ground-vau! $with-subshell (cmd opts . body) denv
  ($define! cmd (eval cmd denv))
  (with-signals-for-subprocess
    ($lambda ()
      (redirect-launch
        ($lambda ()
          (execve "/bin/sh" (list "/bin/sh" "-c" cmd)))
        opts
        body
        denv))))

