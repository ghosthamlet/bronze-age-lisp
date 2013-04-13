;;;
;;; printer.k
;;;
;;; Printing of lisp values.
;;;

;;
;; printer flags
;;
;;  unicode ... allow use of non-ascii characters on output
;;  share   ... print shared substructures using datum labels
;;  color   ... print in color using ANSI terminal escape sequences
;;  escape  ... if #t, print like (write ...), if #f, print like (display ...)
;;
;; extension:
;;
;;   ($get-printer-flag <SYMBOL>)
;;
;;     Returns value of printer flag designated by <SYMBOL>.
;;
;;   ($with-printer-flags <BINDINGS> . <BODY>)
;;
;;     Evaluate forms of <BODY> with printer flags set
;;     according to <BINDINGS>. <BINDINGS> have the
;;     same form as in $bindings->environment.
;;
($bind-private! get-printer-flags ())
($bind-private! bind-printer-flags ())

(init-forms-add!
  ($quote
    ($define! (bind-printer-flags get-printer-flags)
      (make-keyed-dynamic-variable*
        ($bindings->environment
          (unicode #f)
          (color #f)
          (share #t)
          (escape #t))))))

($define-ground-vau! $get-printer-flag (flag) #ignore
  (eval flag (get-printer-flags)))

($define-ground-vau! $with-printer-flags (flags . body) denv
  (bind-printer-flags
    (make-environment
      (eval (cons $bindings->environment flags) denv)
      (get-printer-flags))
    (eval (list* $lambda () body) denv)))

($define-ground-lambda! write-simple args
  ($with-printer-flags ((share #f)) (apply write args)))

($define-ground-lambda! display args
  ($with-printer-flags ((escape #f)) (apply write args)))

($define-ground-lambda! write (x . r)
  ($let1 p ($if (null? r) stdout (car r))
    (write-aux
      x
      (list (shared-structure-indicator
              ($if ($get-printer-flag share) x #inert))
            ()
            0
            ($if ($get-printer-flag color) 0 #f))
      p)
    (flush-output-port p)))

($defun-privates!
  (write-shared (x s p)
    ($if ((car s) x)
      ($sequence
        ($define! (#ignore a n . #ignore) s)
        ($define! z (assq x a))
        (write-char #\# p)
        ($if (pair? z)
          ($sequence
            (write-number (cdr z) 10 p)
            (write-char #\# p))
          ($sequence
            (write-number n 10 p)
            (write-char #\= p)
            (set-car! (list-tail s 1) (cons (cons x n) a))
            (set-car! (list-tail s 2) (+ 1 n))
            (write-aux x s p))))
      (write-aux x s p)))
  (write-aux (x s p)
    ($cond
      ((pair? x)
        (write-colored-parenthesis #\( s p)
        (write-shared (car x) s p)
        (write-tail (cdr x) s p))
      ((number? x)
        ($cond
          ((fixint? x)
            (write-number x 10 p))
          ((bigint? x)
            (write-string "#[bigint]" p)) ;; TODO
          (#t
            ($if ($get-printer-flag unicode)
              ($sequence
                (write-char ($if (positive? x) #\+ #\-))
                (write-char (integer->char #x221E)))
              (write-string
                ($if (positive? x) "#e+infinity" "#e-infinity")
                p)))))
      ((inert? x)
        (write-string "#inert" p))
      ((ignore? x)
        (write-string "#ignore" p))
      ((null? x)
        (write-string "()" p))
      ((string? x)
        ($if ($get-printer-flag escape)
          ($sequence
            (write-char #\" p)
            (write-string-data (open-input-string x) p)
            (write-char #\" p))
          (write-string x p)))
      ((symbol? x)
        (write-string-like-symbol (symbol->string x) p))
      ((keyword? x)
        (write-string "#:" p)
        (write-string-like-symbol (keyword->string x) p))
      ((char? x)
        ($if ($get-printer-flag escape)
          ($sequence
            (write-string "#\\" p)
            (write-char-char x p))
          (write-char x p)))
      ((eq? x #t)
        (write-string "#t" p))
      ((eq? x #f)
        (write-string "#f" p))
      ((eof-object? x)
        (write-string "#[eof]" p))
      ((applicative? x)
        (write-string "#[applicative]" p))
      ((operative? x)
        (write-string "#[operative]" p))
      ((environment? x)
        (write-string "#[environment]" p))
      ((port? x)
        (write-string "#[port]" p))
      ((continuation? x)
        (write-string "#[continuation]" p))
      ((vector? x)
        (write-string "#[vector]" p))
      ((error-object? x)
        (write-string "#[error " p)
        (write-shared (error-object-message x) s p)
        (write-string "]" p))
      (#t (write-string "#[encapsulation]" p))))
  (write-tail (x s p)
    ($cond
      ((null? x)
        (write-colored-parenthesis #\) s p))
      (($and? (pair? x) (not? ((car s) x)))
        (write-char #\space p)
        (write-shared (car x) s p)
        (write-tail (cdr x) s p))
      (#t
        (write-string " . " p)
        (write-shared x s p)
        (write-colored-parenthesis #\) s p))))
  (write-colored-parenthesis (c s p)
    ($let ((k (list-ref s 3)))
      ($if (integer? k)
        ($let (((a b) ($if (eq? c #\()
                        (list k (+ k 1))
                        (list (- k 1) (- k 1)))))
          (set-car! (list-tail s 3) b)
          (write-string "\x1B;[3" p)
          (write-char (integer->char (+ #x31 (mod a 5))) p)
          (write-char #\m p)
          (write-char c p)
          (write-string "\x1B;[m" p))
        (write-char c p))))
  (write-char-char (c p)
    ($cond
      ((eq? c #\newline) (write-string "newline" p))
      ((eq? c #\space) (write-string "space" p))
      ((char<=? #\newline c #\x7D) (write-char c p))
      (#t
        (write-char #\x p)
        (write-string (number-digits (char->integer c) 16) p))))
  (write-string-char (c p)
    ($cond
      ((eq? c #\\) (write-string "\\\\" p))
      ((eq? c #\") (write-string "\\\"" p))
      ((char<=? #\x20 c #\x7D) (write-char c p))
      ((eq? c #\newline) (write-string "\\n" p))
      (#t
        (write-string "\\x" p)
        (write-string (number-digits (char->integer c) 16) p)
        (write-char #\; p))))
  (write-string-data (p q)
    ($let1 c (read-char p)
      ($unless (eof-object? c)
        (write-string-char c q)
        (write-string-data p q))))
  (write-number (n b p)
    ($if (<? n 0)
      ($sequence
        (write-char #\- p)
        (write-string (number-digits (- 0 n) b) p))
      (write-string (number-digits n b) p)))
  (write-string-like-symbol (s p)
    ($if (simple-string? (open-input-string s))
      (write-string s p)
      ($sequence
        (write-char #\| p)
        (write-string-data (open-input-string s) p)
        (write-char #\| p))))
  (simple-string-tail? (p)
    ($let1 c (read-char p)
      ($or?
        (eof-object? c)
        ($and? ($or? (char-alphabetic? c)
                     (char<=? #\0 c #\9)
                     (memq? c extended-identifier-characters))
               (simple-string-tail? p)))))
  (simple-string? (p)
    ($let1 c (read-char p)
      ($cond
        ((eq? c #\.)
          ($and? (not? (eof-object? (peek-char p)))
                 (simple-string-tail? p)))
        (#t
          ($and?
            (char? c)
            ($or? (char-alphabetic? c)
                  (memq? c extended-identifier-characters))
            (simple-string-tail? p)))))))

($bind-private! number-digits
  (make-bounded-applicative
    (list 2 2) (list "app_number_digits.A2") ()))

($define-ground-lambda! number->string (x . r)
  ($let1 p (open-output-string)
    (write-number x ($if (pair? r) (car r) 10) p)
    (get-output-string p)))

($define-ground-lambda! newline r
  ($let1 p ($if (pair? r) (car r) stdout)
    (write-char #\newline p)
    (flush-output-port p)))
