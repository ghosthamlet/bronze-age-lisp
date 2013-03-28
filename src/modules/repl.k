;;;
;;; repl.k
;;;
;;; Stand-alone interpreter and read-eval-print-loop.
;;;

($define-ground-lambda! read-eval-print-loop (env)
  (repl-loop env)
  (newline))

($define-ground-lambda! stand-alone-interpreter ()
  ($let1 args (get-interpreter-arguments)
    ($if (<? (length args) 2)
      (read-eval-print-loop (make-kernel-standard-environment))
      (process-interpreter-arguments
        (cdr args) #f (make-kernel-standard-environment)))))

($defun-privates!
  (repl-loop (env)
    ($unless (eof-object? (read-eval-print env))
      (repl-loop env)))
  (read-eval-print (env)
    (guard-dynamic-extent
      ()
      ($lambda ()
        (flush-output-port stderr)
        (write-string ">> ")
        (flush-output-port stdout)
        ($let1 input (read)
          ($if (eof-object? input)
            input
            ($let1 result (eval input env)
              ($set! env % result)
              (write result)
              (write-char #\newline)))))
      (list
        (list error-continuation (unwrap repl-error)))))
  (repl-error (x divert)
    ($let1 port stdout ;stderr
      (write-string "ERROR: " port)
      (flush-output-port port)
      ($if (error-object? x)
        ($sequence
          (write-string (error-object-message x) port)
          (write-string "\n    irritants: " port)
          (write (error-object-irritants x) port)
          (write-string "\n    source: " port)
          (write (error-object-source x) port)
          (write-char #\newline))
        ($sequence
          (write x port)
          (write-char #\newline port)))
      (flush-output-port port))
    (divert))
  (print-usage-instructions ()
    (write-string "usage: bronze [-l FILE] [-e EXPR] [-iv] [script]" stderr)
    (newline stderr)
    #f)
  (print-version ()
    (write-string interpreter-version stderr)
    (newline stderr)
    #t)
  (process-interpreter-arguments (args interactive env)
    ($cond
      ((null? args)
        ($when interactive (read-eval-print-loop env)))
      (($or? (equal? (car args) "--help")
             (equal? (car args) "-h"))
        (print-usage-instructions))
      (($or? (equal? (car args) "--version")
             (equal? (car args) "-v"))
        (print-version))
      ((equal? (car args) "-l")
        (eval (list load (cadr args)) env)
        #1=(process-interpreter-arguments (cddr args) interactive env))
      ((equal? (car args) "-e")
        (eval (read (open-input-string (cadr args))) env)
        #1#)
      ((equal? (car args) "-i")
        (process-interpreter-arguments (cdr args) #t env))
      (#t
        ($if interactive
          ($sequence
            #2=(eval (list load (car args)) env)
            (read-eval-print-loop env))
          #2#)))))
