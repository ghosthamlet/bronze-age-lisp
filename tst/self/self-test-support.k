;;;
;;; self-test-support.k
;;;
;;; Support for testing.
;;;
;;; Do not merge into files from other test directories.
;;; Keep the test groups independent.
;;;

($unless ($binds? (get-current-environment) display)
  ($define! display write-string))

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

($define! protect-call
  ($lambda (proc)
    (guard-dynamic-extent
      ()
      ($lambda () (list "return" (proc)))
      (list
        (list error-continuation
              ($lambda (x divert)
                (divert "error"
                        (error-object-message x)
                        (error-object-irritants x))))
        (list root-continuation
              ($lambda (x divert) (divert "exit" x)))))))

($define! protect-eval
  ($lambda (obj env)
    (protect-call
      ($lambda () (eval (copy-es-immutable obj) env)))))

($define! fail-with-report
  ($lambda (id arg sut ref)
    (fail)
    (display "  FAIL ") (write id)
    (display "\n    test expression:  ") (write arg)
    (display "\n    test result:      ") (write sut)
    (display "\n    reference result: ") (write ref)
    (newline)))
