;;;
;;; repl.k
;;;
;;; Stand-alone interpreter and read-eval-print-loop.
;;;
;;; Command line usage is mostly compatible with klisp:
;;;
;;;   bronze.bin [OPTIONS] [SCRIPT.k [SCRIPT-ARGS]]
;;;
;;;    -e EXPR        evaluate EXPR
;;;
;;;    -w EXPR        evaluate EXPR and print result to stdout
;;;
;;;    -l FILE        load FILE and continue processing arguments,
;;;                   equivalent to -e '(load "FILE")'
;;;
;;;    -r FILE        equivalent to -e '(require "FILE")'
;;;
;;;    -i             force interactive REPL
;;;
;;;    -b             disable color output and line editing in REPL
;;;
;;;    -              read expressions from STDIN and evaluate
;;;                   one-by-one
;;;
;;;    -v, --version  print version string
;;;    -h, --help     print short help
;;;
($define-ground-lambda! read-eval-print-loop (env)
  (with-signal-handler
    (list #:sigint
          ($lambda #ignore
            (error "User interupt (caught SIGINT).")))
    ($lambda ()
      ($with-printer-flags
        ((color
          ($if ($and? ($binds? env %dumb)
                      (eq? ($remote-eval %dumb env) #t))
            #f
            #:if-terminal))
         (unicode
            #t))
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

($bind-private! repl-completion-strings
  ($quote* "#:inert"
           "#:ignore"
           "#e+infinity"
           "#e-infinity"
           "$define!"
           "load"
           "$vau"
           "$lambda"))

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
              (line (read-edit ">> " history repl-completion-strings)))
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
    (print-error-object x stdout)
    (divert))
  (interpret-stdin (env)
    . #9=(($define! x (copy-es-immutable (read)))
          ($unless (eof-object? x)
            (eval x env)
            . #9#)))
  (print-usage-instructions ()
    (write-string "usage: bronze [-l FILE] [-e EXPR] [-w EXPR] [-i] [-b] [-v] [SCRIPT [ARGS...]]" stderr)
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
        ($abort-on-error args (eval (list load (cadr args)) env))
        #1=(process-interpreter-arguments (cddr args) interactive env))
      ((equal? (car args) "-r")
        ($abort-on-error args (require (cadr args)))
        #1#)
      ((equal? (car args) "-e")
        ($abort-on-error args (eval-string (cadr args) env))
        #1#)
      ((equal? (car args) "-w")
        ($abort-on-error args
          (write (eval-string (cadr args) env))
          (newline))
        #1#)
      ((equal? (car args) "-i")
        (process-interpreter-arguments (cdr args) #t env))
      ((equal? (car args) "-b")
        ($set! env %dumb #t)
        (process-interpreter-arguments (cdr args) #t env))
      ((equal? (car args) "-")
        ($set! private-environment script-arguments args)
        ($if interactive
          ($sequence
            #8=($abort-on-error #inert (interpret-stdin env))
            (newline)
            (read-eval-print-loop env))
          #8#))
      (#t
        ($set! private-environment script-arguments args)
        ($if interactive
          ($sequence
            #2=($abort-on-error #inert (eval-sequence ($abort-on-error args (read-file (car args))) env))
            (read-eval-print-loop env))
          #2#)))))

($define-private-vau! $abort-on-error (arg-pos . body) denv
  (guard-dynamic-extent
    ()
    ($lambda () (eval-sequence body denv))
    (list (list error-continuation
                ($lambda (x divert)
                  (print-error-object x stderr)
                  ($define! arg-pos (eval arg-pos denv))
                  ($when (finite-list? arg-pos)
                    (format stderr
                      "  The error occured while processing the command line arguments ~w.\n"
                      (take-at-most-n 2 arg-pos)))
                  (exit 1))))))
