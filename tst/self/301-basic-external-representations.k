;;;
;;; 301-basic-external-representation.k
;;;
;;; Test reader and printer.
;;;

($define! $r
  ($vau (ext int) #ignore
    ($define! read-result
      (protect-call ($lambda () (read (open-input-string ext)))))
    ($if (equal? read-result (list "return" int))
      (pass)
      (fail-with-report "read" ext read-result int))))

($define! $w
  ($vau (ext int) #ignore
    ($define! write-result
      (protect-call
        ($lambda ()
          ($let ((p (open-output-string)))
            (write int p)
            (get-output-string p)))))
    ($if (equal? write-result (list "return" ext))
      (pass)
      (fail-with-report "write" int write-result ext))))

($define! $rw
  ($vau args denv
    (eval (cons $r args) denv)
    (eval (cons $w args) denv)))

;; special tokens
;;
($rw "#t" #t)
($rw "#f" #f)
($rw "#inert" #inert)
($rw "#ignore" #ignore)

;; small decimal numbers (canonical representation)
;;
($rw "-42" -42)
($rw "-2" -2)
($rw "-1" -1)
($rw "0" 0)
($rw "1" 1)
($rw "2" 2)
($rw "42" 42)

;; noncanonical number representation
;;
($r "+0" 0)
($r "+1" 1)

;; small binary, hexadecimal and octal numbers (reader)
;;
($r "#b101010" 42)
($r "#o15" 13)
($r "#x10" 16)
($r "#xFF" 255)

;; ascii characters
;;
($rw "#\\a" #\a)
($rw "#\\Z" #\Z)
($rw "#\\+" #\+)
($rw "#\\\"" #\")

;; space and newline (canonical, test reader and printer)
;;
($rw "#\\space" #\space)
($rw "#\\newline" #\newline)

;; R7RS character names (reader only)
;;
($r "#\\alarm" #\alarm)
($r "#\\backspace" #\backspace)
($r "#\\delete" #\delete)
($r "#\\escape" #\escape)
($r "#\\null" #\null)
($r "#\\return" #\return)
($r "#\\tab" #\tab)

;; characters specified by hexadecimal constant (canonical)
;;
($rw "#\\x7F" #\x7F)
($rw "#\\x3BB" #\x3BB)
($rw "#\\x1" #\x1)

;; unicode character constants (reader only)
;;
($r "#\\§" #\x00A7)
($r "#\\λ" #\x03BB)
($r "#\\Č" #\x010C)

;; symbols and keywords (canonical representation)
;;
($rw "abc" abc)
($rw "x1" x1)
($rw "$let*" $let*)
($rw "string->symbol" string->symbol)
($rw "+" +)
($rw "-" -)
($rw "/" /)
($rw ".a" .a)
($rw "..." ...)
($rw "|s p a c e s|" |s p a c e s|)
($rw "|.|" |.|)
($rw "#:abc" #:abc)
($rw "#:k>e<y-w_o%r@d" #:k>e<y-w_o%r@d)
($rw "#:**1-c" #:**1-c)
($rw "#:string->symbol" #:string->symbol)
($rw "#:+" #:+)
($rw "#:|s p a c e s|" #:|s p a c e s|)
($rw "#:|0123|" #:|0123|)
($rw "||" ||)
($rw "#:||" #:||)

;; noncanonical symbols and kewords
;;
($r "|pqr|" pqr)
($r "#:0123" #:|0123|)

;; lists (canonical representation)
;;
($rw "()" ())
($rw "(1)" (1))
($rw "(1 2)" (1 2))
($rw "(1 2 3 4 3 2 1 2 3 4)" (1 2 3 4 3 2 1 2 3 4))
($rw "(1 2 3 . 4)" (1 2 3 . 4))

;; non-canonical representation
;;
($r "(1 . (2 . (3 . (4 . ()))))" (1 2 3 4))

;; whitespace and comments (test reader)
;;
($r "    1" 1)
($r "( 2 )" (2))
($r "( 3 . 4 )" (3 . 4))
($r "( 5 . 6 )" (5 . 6))
($r "\n\t2" 2)
($r " (\t2\n1 ) " (2 1))
($r " ;123\n456\n" 456)
($r " ( ;123\n (2))" ((2)))
($r "((2) ;123\n (3))" ((2) (3)))
($r "((2) . ;123\n (3))" ((2) 3))
($r "((2) . 4 ;123\n)" ((2) . 4))
($r "#|xxx|# 1" 1)
($r "#|#||#|# 2" 2)
($r "#|nested#|#|block|#|#comment|# 3" 3)
($r "(#|c|#)" ())
($r "(2 #|c|# 3)" (2 3))
($r "(3 . #|c|# 4)" (3 . 4))
($r "(5 #|c|# . 6)" (5 . 6))
($r "(7 . 8 #|c|#)" (7 . 8))

(summary)
