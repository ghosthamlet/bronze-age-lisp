;;;
;;; 309-basic-format-string.k
;;;
;;; Test (format ...).
;;;

($define! $t
  ($vau (fmt-args expected) denv
    ($define! result
      (protect-call
        ($lambda () (apply format fmt-args))))
    ($if (equal? result (list "return" expected))
      (pass)
      (fail-with-report "format" (cons ($quote format) fmt-args) result expected))))

;; plain strings
;;
($t ("") "")
($t ("x") "x")
($t ("xyz") "xyz")

;; directives
;;
($t ("~~") "~")
($t ("~%") "\n")
($t ("~a" (1 "2" 3)) "(1 2 3)")
($t ("~s" (1 "2" 3)) "(1 \"2\" 3)")
($t ("~c" #\tab) "\t")
($t ("~d" 1234) "1234")
($t ("~b" 1234) "10011010010")
($t ("~o" 1234) "2322")
($t ("~x" 1234) "4D2")

;; whitespace
;;
($t ("x~ y") "xy")
($t ("x~ \t v") "xv")
($t ("line1~
      line2~ \t\r
      line3") "line1line2line3")
($t ("line1~

 line2
 line3") "line1\n line2\n line3")

(summary)
