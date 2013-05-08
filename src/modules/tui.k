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
    ((#\escape #\[ #\A)       . #:up)
    ((#\escape #\[ #\B)       . #:down)
    ((#\escape #\[ #\C)       . #:right)
    ((#\escape #\[ #\D)       . #:left)
    ((#\escape #\[ #\H)       . #:home) ; xterm
    ((#\escape #\[ #\F)       . #:end)
    ((#\escape #\[ #\1 #\x7E) . #:home) ; linux console
    ((#\escape #\[ #\4 #\x7E) . #:end)
    ((#\escape #\[ #\3 #\~)   . #:delete)
    (#\x7F                    . #:backspace)
    (#\x08                    . #:backspace)
    (#\x09                    . #:tab)
    (#\x0D                    . #:return)
    (#\x1B                    . #:escape)))

($defun-privates!
  (parse-cursor-position-report (p)
    ($let1 c (peek-char p)
      ($cond
        ((eof-object? c)
          ())
        ((char-digit? c)
          (cons (read-unsigned-number p 10)
                (parse-cursor-position-report p)))
        (#t
          (read-char p)
          (parse-cursor-position-report p))))))

;;
;; reading string with parenthesis higlighting
;; and simple history buffer
;;
;; (read-edit PROMPT HISTORY COMPLETIONS) => string or eof-object
;;
;; where PROMPT is a string
;;   and HISTORY and COMPLETIONS are lists of strings
;;
;; assuming that stdin is a terminal
;;
($define-ground-lambda! read-edit (prompt history completion-strings)
  ($letrec
    ((env (get-current-environment))
     (history-index -1)
     (history-length (length history))
     (completion-lists ($lazy (map string->list completion-strings)))
     (edit-width 60)
     (show
        ($lambda (left right)
          (write-string "\x1B;[0G\x1B;[K")
          (write-string "\x1B;[1m")
          (write-string prompt)
          (write-string "\x1B;[0m")
          ($define! (left right) (highlight-parentheses left right))
          ($define! (left right) (trim-display left right edit-width))
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
        ($unless (char-ready?)
          (show left right))
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
            ((eq? c #:return)
              ($if (null? left right)
                (edit left right)
                ($let1 final (final-fix (append (reverse left) right))
                  (show-final final)
                  final)))
            ((eq? c #:tab)
              ($let1 prefix (take-word-chars-reversed left ())
                ($let1 completions
                       (filter pair?
                         (map ($lambda (x) (discard-prefix prefix x))
                           (force completion-lists)))
                  ($if (=? 1 (length completions))
                    (edit (append (list #\space)
                                  (reverse (car completions))
                                  left)
                          right)
                    (edit left right)))))
            ((eq? c #\x4)
              ($if (null? left right)
                ($sequence
                  (show-final "(EOF)")
                  ;; synthetise eof-object
                  (read-char (open-input-string "")))
                (edit () ())))
            (($and? (char? c) (char<=? #\space c))
              (edit (cons c left) right))
            (($and? (pair? c)
                    (eq? (car c) #\escape)
                    (memq? #\; c)
                    (memq? #\R c))
              ($let* (((rows cols) (parse-cursor-position-report
                                     (open-input-string (list->string c))))
                      (cols (min 160 (max 20 cols))))
                ($set! env edit-width
                  (- cols 1 (string-length prompt))))
              (edit left right))
            (#t
              (edit left right)))))))
    (with-noncanonical-input
      ($lambda ()
        ;; Read terminal width. Attempt to move the cursor to invalid
        ;; column 999 and then read the cursor position. The terminal
        ;; responds with CSI sequence, which is read out in the main
        ;; loop of the line editor.
        (write-string "\x1B;[199G\x1B;[6n")
        (flush-output-port)
        (edit () ())))))

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
        (list left right))))
  (take-word-chars-reversed (cs acc)
    ($if ($and? (pair? cs)
                ($or? (char-alphabetic? (car cs))
                      (memq? (car cs) extended-identifier-characters)
                      (eq? (car cs) #\#)))
        (take-word-chars-reversed (cdr cs) (cons (car cs) acc))
        acc))
  (discard-prefix (prefix lst)
    ($cond
      ((null? prefix) lst)
      ((null? lst) #f)
      ((char=? (car prefix) (car lst))
        (discard-prefix (cdr prefix) (cdr lst)))
      (#t #f)))
  (final-fix (cs)
    ($let ((str (list->string cs)))
      ($if (char=? (car cs) #\()
        str
        (guard-dynamic-extent
          ()
          ($lambda ()
            ($let1 rs (read-all (open-input-string str) ())
              ($if ($and? (>=? (length rs) 2) (symbol? (car rs)))
                ($let1 p (open-output-string)
                  (write rs p)
                  (get-output-string p))
                str)))
          (list (list error-continuation
                      ($lambda (obj divert)
                        (apply divert str))))))))
  (take (xs n)
    ($if (<? 0 n)
      (cons (car xs) (take (cdr xs) (- n 1)))
      ()))
  (trim-display (left right w)
    ($let ((nl (length left)) (nr (length right)))
      ($cond
        ((<=? (+ nl nr) w)
          (list left right))
        ((<=? nl nr)
          ($if (<? (* 2 nl) w)
            (list left (take right (- w nl)))
            (list (take left (div w 2)) (take right (- w (div w 2))))))
        (#t
          (reverse (trim-display right left w)))))))
