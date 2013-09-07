;;;
;;; read.k
;;;
;;; Lisp reader.
;;;

#|
($define! $define-ground-lambda!
  ($vau (name args . body) denv
    (eval (list $define! name (list* $lambda args body))
          denv)))

($define! $bind-private! $define!)
($define! $quote* (unwrap list))
($define! $let1
  ($vau (sym val . body) denv
    (eval (list* $let (list (list sym val)) body) denv)))
($define! $defun-privates!
  ($vau items denv
    (for-each
      ($lambda ((name args . body))
        (eval (list $define! name (list* $lambda args body))
              denv))
      items)))

($define! ttk
  ($lambda (s)
    ($let ((p (open-input-string s)))
      (list (read-token p) (read-token p) (read-token p)))))

($define! tr
  ($lambda (s)
    (read-aux (open-input-string s))))
|#


($define-ground-lambda! read r
  (read-aux
    ($if (null? r)
      ($sequence
        (flush-output-port stdout)
        (flush-output-port stderr)
        stdin)
      (car r))))

;;
;; (read-signed-number PORT BASE)
;; (read-unsigned-number PORT BASE)
;; (string->number STRING [BASE])
;;

($defun-privates!
  (parse-error (p . args)
    ($when (environment? p)
      ($define! p ($remote-eval port p)))
    (apply error
      (append args (get-textual-input-position p))))
  (read-signed-number (p b)
    ($let1 c (peek-char p)
      ($cond
        ((eof-object? c) (parse-error p "read-number EOF"))
        ((eq? c #\-) (read-char p) (negate (read-unsigned-number p b)))
        ((eq? c #\+) (read-char p) (read-unsigned-number p b))
        (#t (read-unsigned-number p b)))))
  (read-unsigned-number (p b)
    ($let1 c (read-char p)
      ($if ($and? (char? c) (char-digit? c b))
        (read-number-tail p b (char->digit c b))
        (parse-error p "read-unsigned-number"))))
  (read-number-tail (p b a)
    ($let1 c (peek-char p)
      ($if ($and? (char? c) (char-digit? c b))
         ($sequence
           (read-char p)
           (read-number-tail p b (+ (char->digit c b) (* b a))))
          a))))

($define-ground-lambda! string->number (s . r)
  ($let1 p (open-input-string s)
    ($let1 b ($if (null? r) 10 (car r))
      ($let1 n (read-signed-number p b)
        ($if (eof-object? (read-char p))
          n
          (error "string->number" s b))))))

;;
;; (read-token p)
;;

($bind-private! t-left  ($quote* #\())
($bind-private! t-right ($quote* #\)))
($bind-private! t-dot   ($quote* #\.))

($bind-private! special-tokens
  ($quote*
    ("ignore" . #ignore)
    ("inert" . #inert)
    ("t" . #t)
    ("f" . #f)
    ("e+infinity" . #e+infinity )
    ("e-infinity" . #e-infinity )
   ; ("i+infinity" . 999)
   ; ("i-infinity" . -999)
   ; ("e-infinity" . -999)
   ; ("undefined" . "?undefined")
   ; ("real" . "?real")
   ; ("e-infinity" . -999)
    ))

($bind-private! character-names
  ($quote*
    ("null" . #\x0000)
    ("alarm" . #\x0007)
    ("backspace" . #\x0008)
    ("tab" . #\x0009)
    ("newline" . #\x000A)
    ("return" . #\x000D)
    ("escape" . #\x001B)
    ("space" . #\x0020)
    ("delete" . #\x007F)))

($bind-private! extended-identifier-characters
  ($quote*
    #\! #\$ #\% #\& #\* #\+ #\- #\. #\/ #\:
    #\< #\= #\> #\? #\@ #\^ #\_ #\~))

($bind-private! read-token-cases
  ($quote*
    (#\; . ($sequence (skip-line p) (read-token p)))
    (#\( . t-left)
    (#\) . t-right)
    (#\. . ($let1 c (peek-char p)
             ($cond
               (($or? (char-alphabetic? c)
                      (memq? c extended-identifier-characters))
                 (string->symbol
                   (get-output-string
                     (read-symbol-tail p (open-output-string* #\.)))))
               ((char-digit? c)
                 (parse-error p "reader: dot followed by a digit is not supported syntax"))
               (#t
                 t-dot))))
    (#\+ . #1=(read-number-or-symbol c p))
    (#\- . #1#)
    (#\# . (read-special p))
    (#\" . (get-output-string
             (read-string-tail p (open-output-string))))
    (#\| . (string->symbol
             (get-output-string
               (read-barsymbol-tail p (open-output-string)))))))

($bind-private! read-special-token-cases
  ($quote*
    (#\\ . (read-character-literal p))
    (#\x . (read-signed-number p 16))
    (#\d . (read-signed-number p 10))
    (#\o . (read-signed-number p 8))
    (#\b . (read-signed-number p 2))
    (#\! . ($sequence (skip-line p) (read-token p)))
    (#\| . ($sequence (skip-block-comment 1 (read-char p) p)
                      (read-token p)))
    (#\; . ($sequence (read-aux p) (read-token p)))))

($defun-privates!
  (read-token (p)
    ($let1 c (read-char p)
      ($cond
        ((eof-object? c)      c)
        ((char-whitespace? c) (read-token p))
        (#t
          ($let1 t (assq c read-token-cases)
            ($cond
              ((pair? t)
                (eval (cdr t) (get-current-environment)))
              ((char<=? #\0 c #\9)
                (read-number-tail p 10 (char->digit c 10)))
              (($or? (char-alphabetic? c)
                     (memq? c extended-identifier-characters))
                (string->symbol
                  (get-output-string
                    (read-symbol-tail p (open-output-string* c)))))
              (#t
                (parse-error p "invalid character on input" c))))))))
  (read-special (p)
    ($let* ((c (read-char p))
            (t (assq c read-special-token-cases)))
      ($cond
        ((pair? t)
          (eval (cdr t) (get-current-environment)))
        ((eq? c #\:)
          ($let1 d (read-char p)
            (string->keyword
              (get-output-string
                ($cond
                  ((eq? d #\|)
                    (read-barsymbol-tail p (open-output-string)))
                  (($or? (char-alphabetic? d)
                         (char-digit? d)
                         (memq? d extended-identifier-characters))
                    (read-symbol-tail p (open-output-string* d)))
                  (#t
                    (parse-error p "invalid keyword")))))))
        ((char<=? #\0 c #\9)
          ($let* ((n (read-number-tail p 10 (char->digit c 10)))
                  (k (read-char p)))
            ($if ($or? (eq? k #\=) (eq? k #\#))
              (list k n)
              (parse-error p "invalid S-expression label" n k))))
        (#t
          ($let1 s (get-output-string
                     (read-symbol-tail p (open-output-string* c)))
            ($let1 x (assoc s special-tokens)
              ($if (null? x)
                (parse-error p "invalid special token" s c)
                (cdr x))))))))
  (read-character-literal (p)
    ($let* ((c1 (read-char p))
            (c2 (peek-char p)))
      ($cond
        (($and? (eq? c1 #\x)
                (char? c2)
                (char-digit? c2 16))
          (integer->char (read-unsigned-number p 16)))
        (($and? (char-alphabetic? c1)
                (char? c2)
                (char-alphabetic? c2))
          ($let1 s (get-output-string
                     (read-symbol-tail p (open-output-string* c1)))
            ($let1 x (assoc s character-names)
              ($if (null? x)
                   (parse-error p "invalid character name" s)
                   (cdr x)))))
        (#t c1))))
  (skip-line (p)
    ($let1 c (read-char p)
      ($unless ($or? (eof-object? c) (eq? c #\newline))
        (skip-line p))))
  (skip-block-comment (n c0 p)
    ($let1 c1 (read-char p)
      ($cond
        ((eof-object? c1)
          (parse-error p "unterminated #|block|# comment"))
        (($and? (eq? c0 #\#) (eq? c1 #\|))
          (skip-block-comment (+ n 1) (read-char p) p))
        (($and? (eq? c0 #\|) (eq? c1 #\#))
          ($when (<? 1 n)
            (skip-block-comment (- n 1) (read-char p) p)))
        (#t
          (skip-block-comment n c1 p)))))
  (read-string-tail (p q)
    ($let1 c (read-char p)
      ($cond
        ((eof-object? c)
          (parse-error p "unexpected EOF in quoted string"))
        ((eq? c #\")
          q)
        ((eq? c #\\)
          (write-char (read-string-char-escape p) q)
          (read-string-tail p q))
        (#t
          (write-char c q)
          (read-string-tail p q)))))
  (read-barsymbol-tail (p q)
    ($let1 c (read-char p)
      ($cond
        ((eof-object? c)
          (parse-error p "unexpected EOF in quoted symbol"))
        ((eq? c #\|)
          q)
        ((eq? c #\\)
          (write-char (read-string-char-escape p) q)
          (read-barsymbol-tail p q))
        (#t
          (write-char c q)
          (read-barsymbol-tail p q)))))
  (read-symbol-tail (p q)
    ($let1 c (peek-char p)
      ($cond
        ((eof-object? c) q)
        ((eq? c #\\)
          (read-char p)
          (write-char (read-string-char-escape p) q)
          (read-symbol-tail p q))
        (($or? (char-alphabetic? c)
               (char-digit? c)
               (memq? c extended-identifier-characters))
          (read-char p)
          (write-char c q)
          (read-symbol-tail p q))
        (#t q))))
  (read-string-char-escape (p)
    ($let1 c (read-char p)
      ($cond
        ((eq? c #\t) #\x0009)
        ((eq? c #\n) #\x000A)
        ((eq? c #\r) #\x000D)
        ((eq? c #\x)
          ($let1 n (read-unsigned-number p 16)
            ($let1 t (read-char p)
              ($unless (eq? t #\;)
                (parse-error p "escape sequence #\\x...; must end with a semicolon"))
              (integer->char n))))
        (#t c))))
  (read-number-or-symbol (c p)
    ($let1 d (peek-char p)
      ($if ($and? (char? d) (char<=? #\0 d #\9))
        ($let1 x (read-unsigned-number p 10)
          ($if (eq? c #\-) (negate x) x))
        (string->symbol
          (get-output-string
            (read-symbol-tail p (open-output-string* c)))))))
  (open-output-string* (c)
    ($let1 q (open-output-string)
      (write-char c q)
      q)))


;;
;; (read-aux PORT)
;;
($defun-privates!
  (read-aux (p)
    ($define! e
      ($bindings->environment (has #f)
                              (buffer ())
                              (port p)
                              (labels ())
                              (result ())))
    (read-form e ($lambda (v) ($set! e res v)))
    ($remote-eval res e))

  (read-aux-token (e)
    ($if ($remote-eval has e)
      ($sequence
        ($set! e has #f)
        ($remote-eval buffer e))
      (read-token ($remote-eval port e))))
  (peek-aux-token (e)
    ($unless ($remote-eval has e)
      ($set! e buffer (read-token ($remote-eval port e)))
      ($set! e has #t))
    ($remote-eval buffer e))

  (read-label-ref (e l)
    ($let1 y (assq l ($remote-eval labels e))
      ($if (pair? y)
        (cdr y)
        (parse-error e "undefined S-expression label" l))))
  (read-label-set! (e l v)
    ($set! e labels (cons (cons l v) ($remote-eval labels e))))

  (read-form (e p!)
    ($let* ((t (read-aux-token e)))
      ($if (pair? t)
        ($cond
          ((eq? t t-left)
            ($if (eq? (peek-aux-token e) t-right)
              ($sequence (p! ()) (read-aux-token e))
              (read-list e p!)))
          ((eq? (car t) #\#)
            (p! (read-label-ref e (cadr t))))
          ((eq? (car t) #\=)
            (read-form e
                       ($lambda (v)
                         (p! v)
                         (read-label-set! e (cadr t) v))))
          (#t
            (parse-error e "read-form: unexpected character" (car t))))
        (p! t))))
  (read-list (e p!)
    ($let ((tmp (cons 0 0)))
      (p! tmp)
      (read-form e ($lambda (v) (set-car! tmp v)))
      (read-tail e ($lambda (v) (set-cdr! tmp v)))))
  (read-tail (e p!)
    ($let ((t (peek-aux-token e)))
      ($cond
        ((eq? t t-right)
          (read-aux-token e)
          (p! ()))
        ((eq? t t-dot)
          (read-aux-token e)
          (read-form e p!)
          ($unless (eq? (read-aux-token e) t-right)
            (parse-error e "expected ) after improper list")))
        ((eof-object? t)
          (parse-error e "unexpected EOF in a list"))
        (#t
          (read-list e p!))))))


;;
;; (load FILE)
;;
($defun-privates!
  (read-all (p a)
    ($let1 x (read p)
      ($if (eof-object? x)
        (reverse a)
        (read-all p (cons x a)))))
  (read-file (s)
    ($let1 p (open-input-file s)
      ($let1 v (read-all p ())
        (close-input-port p)
        v))))

($define-ground-wrapvau! load (s) denv
  (eval (cons $sequence (read-file s)) denv))
