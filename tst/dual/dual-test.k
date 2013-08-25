;;;
;;; dual-test.k
;;;
;;; usage: bronze.bin dual-test.k SUBTEST1.k SUBTEST2.k ...
;;;
;;; Environment for testing built-in combiners against
;;; the respective derivations from Kernel Report.
;;;
;;; TODO: Count difference in error messages separately
;;;       as minor failure.
;;;

($unless ($binds? (get-current-environment) display)
  ($define! display write-string))

($define! naive-for-each
  ($lambda (f xs)
    ($when (pair? xs)
      (f (car xs))
      (naive-for-each f (cdr xs)))))

($define! protect-eval
  ($lambda (obj env)
    (guard-dynamic-extent
      ()
      ($lambda ()
        (list "return" (eval (copy-es-immutable obj) env)))
      (list
        (list error-continuation
              ($lambda (x divert)
                (divert "error"
                        (error-object-message x)
                        (error-object-irritants x))))
        (list root-continuation
              ($lambda (x divert) (divert "exit" x)))))))

($define! (pass fail summary)
  (($lambda ()
    ($define! npass 0)
    ($define! nfail 0)
    ($define! env (get-current-environment))
    (list
      ($lambda () ($set! env npass (+ 1 npass)))
      ($lambda () ($set! env nfail (+ 1 nfail)))
      ($lambda ()
        (display "  ")
        (write npass)
        (display " PASS, ")
        (write nfail)
        (display " FAIL.")
        (newline))))))

($define! account
  ($lambda (f x r1 r2)
    ($cond
      ((equal? r1 r2)
        (pass))
      ((equal? (car r1) (car r2) "error")
        ($if (major-difference-in-error-signalling? (cdr r1) (cdr r2))
          (report-major-failure f x r1 r2)
          (report-minor-failure f x r1 r2)))
      (#t
        (report-major-failure f x r1 r2)))))

($define! major-difference-in-error-signalling?
  ($lambda ((msg1 irr1) (msg2 irr2))
    ($define! similar-messages
      ($or?
        (equal? msg1 msg2)
        (member? (list msg1 msg2)
          ($quote*
            ("Invalid argument structure." "Match failure")
            ("Invalid argument structure." "Cannot traverse list structure.")
            ("Cannot traverse list structure." "Match failure")
            ))))
    ($define! similar-irritants
      ($or?
        (equal? irr1 irr2)
        (equal? irr1 (list irr2))
        (equal? irr2 (list irr1))
        ($and? (not? (null? irr2))
               (substructure? irr2 irr1))))
    ($or? (not? similar-messages)
          (not? similar-irritants))))

($define! substructure?
  ($lambda (small big)
    ($or?
      (equal? small big)
      ($and?
        (pair? big)
        ($or? (substructure? small (car big))
              (substructure? small (cdr big)))))))

($define! report-minor-failure
  ($lambda (f x r1 r2)
    (pass)
    ($when #f ; change to #t to enable printing
      (display "  minor discrepancy in error signalling of ") (write f)
      (display "\n    test expression:  ") (write x)
      (display "\n    test error:       ") (write (cdr r1))
      (display "\n    reference error:  ") (write (cdr r2))
      (newline))))

($define! report-major-failure
  ($lambda (f x r1 r2)
    (fail)
    (display "  FAIL ") (write f)
    (display "\n    test expression:  ") (write x)
    (display "\n    test result:      ") (write r1)
    (display "\n    reference result: ") (write r2)
    (newline)))

($define! $check
  ($vau (symbol reimpl prepare inputs) denv
    ($define! e1 (make-kernel-standard-environment))
    ($define! e2 (make-kernel-standard-environment))
    (eval prepare e1)
    (eval (list $define! symbol reimpl) e2)
    (eval prepare e2)
    (naive-for-each
      ($lambda (expr)
        ($define! r1 (protect-eval expr e1))
        ($define! r2 (protect-eval expr e2))
        (account symbol expr r1 r2))
      inputs)))

($if (<? (length (get-interpreter-arguments)) 3)
  ($sequence
    (display "usage: bronze.bin dual-test.k SUBTSET.k...\n")
    (flush-output-port)
    (apply-continuation root-continuation #f))
  ($sequence
    (naive-for-each load (cddr (get-interpreter-arguments)))
    (summary)))
