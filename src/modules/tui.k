;;;
;;; tui.k
;;;
;;; Text user interface on ANSI terminal (e.g. XTERM).
;;;

;;
;; Translating terminal escape sequences to symbolic
;; key names.
;;
;; (read-key [PORT]) => char,    e.g. #\x0D
;;                      keyword, e.g. #:up)
;;                      list,    e.g. (#\escape ...)
;;
($define-ground-lambda! read-key r
  ($let*
    ((p ($if (null? r) stdin (car r)))
     (c (read-char p))
     (k ($if ($and? (eq? c #\escape) (char-ready? p))
          ($let1 d (read-char p)
            ($cond
              ((eq? d #\[)
                (list* #\escape #\[ (read-control-sequence p)))
              (($or? (eq? d #\O) (eq? d #\N))
                (list #\escape d (read-char p)))
              ((char<=? #\x40 d #\x5F)
                (list #\escape d))
              (#t
                c)))
          c))
     (a (assoc k control-sequence-table)))
    ($if (pair? a) (cdr a) k)))

($define-private-lambda! read-control-sequence (p)
  ($let1 c (peek-char p)
    ($cond
      ((char<=? #\x40 c #\x7E)
        (list (read-char p)))
      ((char<=? #\x20 c #\x3F)
        (cons (read-char p) (read-control-sequence p)))
      (#t
        ()))))

($bind-private! control-sequence-table
  ($quote*
    ((#\escape #\[ #\A)     . #:up)
    ((#\escape #\[ #\B)     . #:down)
    ((#\escape #\[ #\C)     . #:right)
    ((#\escape #\[ #\D)     . #:left)
    ((#\escape #\[ #\H)     . #:home)
    ((#\escape #\[ #\F)     . #:end)
    ((#\escape #\[ #\3 #\~) . #:delete)
    (#\x7F                  . #:backspace)
    (#\x08                  . #:backspace)
    (#\x09                  . #:tab)
    (#\x1B                  . #:escape)))

;;
;; reading string with parenthesis higlighting
;; and simple history buffer
;;
;; (read-edit PROMPT HISTORY) => string or eof-object
;;
;; where PROMPT is a string
;;   and HISTORY is list of strings
;;
;; assuming that stdin is a terminal
;;
($define-ground-lambda! read-edit (prompt history)
  ($letrec
    ((env (get-current-environment))
      (history-index -1)
      (history-length (length history))
      (show
      ($lambda (left right)
        (write-string "\x1B;[0G\x1B;[K")
        (write-string "\x1B;[1m")
        (write-string prompt)
        (write-string "\x1B;[0m")
        ($define! (left right) (highlight-parentheses left right))
        (for-each print-highlighted (reverse left))
        (for-each print-highlighted right)
        ($when (pair? right)
          (write-string "\x1B;[")
          (display (length right))
          (write-char #\D))
        (flush-output-port)))
      (show-final
        ($lambda (s)
        (write-string "\x1B;[0G\x1B;[K")
        (write-string prompt)
        (write-string "\x1B;[1m")
        (write-string s)
        (write-string "\x1B;[0m")
        (newline)))
      (edit
      ($lambda (left right)
        (show left right)
        ($let ((c (read-key)))
          ($cond
            (($and? (eq? c #:backspace) (pair? left))
              (edit (cdr left) right))
            (($and? (eq? c #:left) (pair? left))
              (edit (cdr left) (cons (car left) right)))
            (($and? (eq? c #:right) (pair? right))
              (edit (cons (car right) left) (cdr right)))
            (($and? (eq? c #:delete) (pair? right))
              (edit left (cdr right)))
            ((eq? c #:home)
              (edit () (append (reverse left) right)))
            ((eq? c #:end)
              (edit (append (reverse right) left) ()))
            (($and? (eq? c #:up) (<? history-index (- history-length 1)))
              ($set! env history-index (+ 1 history-index))
              (edit (reverse (string->list (list-ref history history-index))) ()))
            (($and? (eq? c #:down) (<=? 0 history-index))
              ($set! env history-index (+ -1 history-index))
              ($if (negative? history-index)
                (edit () ())
                (edit (reverse (string->list (list-ref history history-index))) ())))
            ((eq? c #\xD)
              ($let ((final (list->string (append (reverse left) right))))
                (show-final final)
                final))
            ((eq? c #\x4)
              ($if (null? left right)
                ($sequence
                  (show-final "(EOF)")
                  ;; synthetise eof-object
                  (read-char (open-input-string "")))
                (edit () ())))
            (($and? (char? c) (char<=? #\space c))
              (edit (cons c left) right))
            (#t
              (edit left right)))))))
    (with-noncanonical-input
      ($lambda () (edit () ())))))

($defun-privates!
  (highlight-one-parenthesis (xs y n)
    ($if (null? xs)
      xs
      ($let (((x . t) xs))
        ($if ($and? (eq? x y) (eq? n 0))
          (cons
            (list #:highlight x)
            t)
          (cons
            x
            (highlight-one-parenthesis t y
              (+ n ($cond ((eq? x #\() 1)
                          ((eq? x #\)) -1)
                          (#t 0)))))))))
  (print-highlighted (x)
    ($if (char? x)
      (write-char x)
      ($sequence
        (write-string "\x1B;[1m")
        (write-char (cadr x))
        (write-string "\x1B;[0m"))))
  (highlight-parentheses (left right)
    ($cond
      (($and? (pair? right) (eq? (car right) #\())
        (list left
              (highlight-one-parenthesis right #\) -1)))
      (($and? (pair? right) (eq? (car right) #\)))
        (list (highlight-one-parenthesis left #\( 0)
              right))
      (($and? (pair? left) (eq? (car left) #\)))
        (list (cons (list #:higlight #\))
                    (highlight-one-parenthesis (cdr left) #\( 0))
              right))
      (#t
        (list left right)))))
