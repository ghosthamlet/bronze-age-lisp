;;;
;;; repl.k
;;;
;;; Stand-alone interpreter and read-eval-print-loop.
;;;

($define-ground-lambda! read-eval-print-loop (env)
  (with-signal-handler
    (list #:sigint
          ($lambda #ignore
            (error "User interupt (caught SIGINT).")))
    ($lambda ()
      ($with-printer-flags
        ((color #:if-terminal)
         (unicode #t))
        (repl-loop env))))
  (newline))

($define-ground-lambda! stand-alone-interpreter ()
  ($let1 args (get-interpreter-arguments)
    ($if (<? (length args) 2)
      (read-eval-print-loop (make-kernel-standard-environment))
      (process-interpreter-arguments
        (cdr args) #f (make-kernel-standard-environment)))))

($bind-private! script-arguments ())
($define-ground-lambda! get-script-arguments () script-arguments)

($defun-privates!
  (repl-loop (env)
    ($unless (eof-object? (read-eval-print env))
      (repl-loop env)))
  (read-eval-print (env)
    (guard-dynamic-extent
      ()
      ($lambda ()
        (flush-output-port stderr)
        ($let1 input (repl-read env)
          ($if (eof-object? input)
            input
            ($let1 result (eval input env)
              ($set! env % result)
              (write result)
              (write-char #\newline)))))
      (list
        (list error-continuation (unwrap repl-error)))))
  (repl-read (env)
    ($if ($and? (color-port? stdout)
                (terminal-port? stdin))
      ($let* ((history ($if ($binds? env %history)
                         ($remote-eval %history env)
                         ()))
              (line (read-edit ">> " history)))
        ($if (eof-object? line)
          line
          ($sequence
            ($set! env %history (repl-add-to-history line history))
            ($let1 value (with-input-from-string line read)
              ($if (eof-object? value)
                (repl-read)
                value)))))
      ($sequence
        (write-string ">> ")  ; dumb mode
        (flush-output-port stdout)
        (read))))
  (repl-add-to-history (h hs)
    ($if ($or? (equal? h "%")
               (equal? h "%history")
               (member? h (take-at-most-n 3 hs)))
      hs
      (take-at-most-n 32 (cons h hs))))
  (take-at-most-n (n xs)
    ($if ($and? (pair? xs) (<? 0 n))
      (cons (car xs) (take-at-most-n (- n 1) (cdr xs)))
      ()))
  (repl-error (x divert)
    ($let1 port stdout ;stderr
      (write-string
        ($if (color-port? port)
          "\x1B;[31;1mERROR:\x1B;[m "
          "ERROR: ")
        port)
      (flush-output-port port)
      ($if (error-object? x)
        ($sequence
          (write-string (error-object-message x) port)
          (write-string "\n    irritants: " port)
          (write (error-object-irritants x) port)
          (write-string "\n    source: " port)
          (write
            ($let1 s (error-object-source x)
              ($if (symbol? s)
                s
                (guess-object-name s #t)))
             port)
          (write-char #\newline))
        ($sequence
          (write x port)
          (write-char #\newline port)))
      (flush-output-port port))
    (divert))
  (interpret-stdin (env)
    . #9=(($define! x (copy-es-immutable (read)))
          ($unless (eof-object? x)
            (eval x env)
            . #9#)))
  (print-usage-instructions ()
    (write-string "usage: bronze [-l FILE] [-e EXPR] [-i] [-v] [SCRIPT [ARGS...]]" stderr)
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
      ((equal? (car args) "-r")
        (require (cadr args))
        #1#)
      ((equal? (car args) "-e")
        (eval (read (open-input-string (cadr args))) env)
        #1#)
      ((equal? (car args) "-i")
        (process-interpreter-arguments (cdr args) #t env))
      ((equal? (car args) "-")
        ($set! private-environment script-arguments args)
        ($if interactive
          ($sequence
            (interpret-stdin env)
            (newline)
            (read-eval-print-loop env))
          (interpret-stdin env)))
      (#t
        ($set! private-environment script-arguments args)
        ($if interactive
          ($sequence
            #2=(eval (list load (car args)) env)
            (read-eval-print-loop env))
          #2#)))))
