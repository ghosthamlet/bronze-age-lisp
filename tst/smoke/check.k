;;;
;;; tst/smoke/check.k
;;;
;;;

($let*
  (((#ignore test-name) (get-script-arguments))
   (input (with-input-from-file test-name read))
   (output (read))
   (expected (eval input (make-kernel-standard-environment))))
  ($if (equal? output expected)
    (exit 0)
    ($sequence
      (display "input (") (display test-name) (display "): ")
      (write input)
      (newline)
      (display "expected output: ")
      (write expected)
      (newline)
      (display "test output:     ")
      (write output)
      (newline)
      (exit 1))))
