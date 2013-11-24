;;;
;;; repl-facilities.k
;;;
;;; Small utilities for the REPL.
;;;
;;; This file defines combiners to be used as commands in the
;;; interpreter's read-eval-print loop.
;;;
;;;  (%r)          Reload files specified by the command line
;;;                options -l" and -r.
;;;
;;;  (! ARGS ...)  Execute operating system shell command. The
;;;                arguments are (display ...)-ed unevaluated,
;;;                separated by spaces and passed to /bin/sh. Simple
;;;                shell commands can be typed quickly because the
;;;                REPL adds the outermost parentheses automatically:
;;;
;;;                   >> ! grep -i string ../doc/reference.txt
;;;
;;;                Beware that the pipe character '|', the semicolon
;;;                ';', stand-alone dot '.' and many other punctuation
;;;                characters have special meaning for the lisp reader
;;;                and won't make it through to the (! ...) operative.
;;;                You can use quoted strings like
;;;
;;;                   >> ! "ls | wc"
;;;
;;;                but you should use (system ...) directly for more
;;;                complex actions.
;;;
;;;  ($time EXPR)  Measure time spend while evaluating EXPR.
;;;

($define! %r
  ($vau () env
    ($define! collect
      ($lambda (acc args)
        ($cond
          ((null? args)
            acc)
          ((equal? (car args) "-l")
            (collect (list* (list load (cadr args)) acc)
                     (cddr args)))
          ((equal? (car args) "-r")
            (collect (list* (list unregister-requirement! (cadr args))
                            (list require (cadr args))
                            acc)
                     (cddr args)))
          ((member? (car args) ($quote* "-e" "-w"))
            (collect acc (cddr args)))
          ((member? (car args) ($quote* "-i" "-b"))
            (collect acc (cdr args)))
          (#t
            acc))))
    ($define! order
      (reverse (collect () (cdr (get-interpreter-arguments)))))
    (for-each
      ($lambda (x) (display "  ") (write x) (newline))
      order)
    (eval (cons $sequence order) env)))

($define! !
  ($vau args #ignore
    (system
      (apply string-append
        (map ($lambda (x) (format " ~a" x)) args)))))

($define! $time
  ($vau (x) denv
    ($let* ((a (get-current-jiffy))
            (y (eval x denv))
            (b (get-current-jiffy))
            ((s r) (div-and-mod (- b a) (get-jiffies-per-second)))
            ((m u) (div-and-mod r 1000))) ; assuming 1 jiffy = 1 microsecond
      (format #t "$time: ~ds ~dms ~dus\n" s m u)
      y)))
