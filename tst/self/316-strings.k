;;;
;;; 316-strings.k
;;;
;;; Test string features.
;;;

;; string-length string-size

($define! $test-string-length-size
  ($vau test-cases denv
    (for-each
      ($lambda ((x . length-and-size))
        ($define! form
          (list ($quote list)
                (list ($quote string-length) x)
                (list ($quote string-size) x)))
        ($define! res (protect-eval form denv))
        ($if (equal? res (list "return" length-and-size))
          (pass)
          (fail-with-report "string length and size"
            form res length-and-size)))
      test-cases)))

($test-string-length-size
  ("" 0 0)
  ("a" 1 1)
  ("ab" 2 2)
  ("01234" 5 5)
  ("αβγδ" 4 8)
  ("道可道非常道" 6 18)
  ("☹☺" 2 6)
  ("\x1F0A1;\x1F0A2;\x1F0A1;" 3 12))

;; string-ref

($define! $test-string-ref
  ($vau (string . test-cases) denv
    (for-each
      ($lambda ((index character))
        ($define! form (list ($quote string-ref) string index))
        ($define! res (protect-eval form denv))
        ($if (equal? res (list "return" character))
          (pass)
          (fail-with-report "string-ref" form res character)))
      test-cases)))

($test-string-ref "0123456789" (0 #\0) (1 #\1) (5 #\5) (8 #\8) (9 #\9))
($test-string-ref "道可道非常道" (0 #\道) (1 #\可) (4 #\常) (5 #\道))

(summary)
