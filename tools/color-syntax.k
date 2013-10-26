;;;
;;; color-syntax.k
;;;
;;; Convert source code in the Kernel Language to HTML.
;;;
;;; Command line usage:
;;;
;;;   The source code is read from the standard input,
;;;   the HTML is printed to the standard output.
;;;
;;;   bronze.bin color-syntax.k <INPUT.k >PAGE.html
;;;
;;;     Print a page with embedded stylesheet.
;;;
;;;   bronze.bin color-syntax.k pre <INPUT.k >PART.html
;;;
;;;     Print only the <pre> element with the source code,
;;;     omit HTML header and stylesheet.
;;;
;;;   bronze.bin color-syntax.k css >EXAMPLE.css
;;;
;;;     Print only the stylesheet.
;;;

($define! usage-msg
"
usage: bronze.bin color-syntax.k css >EXAMPLE.css
       bronze.bin color-syntax.k pre <INPUT.k >PART.html
       bronze.bin color-syntax.k <INPUT.k >PAGE.html
")

($define! css-class-prefix "k-")

($define! example-css
"
.k-comment-1 { color: gray }
.k-comment-2 { color: darkblue }
.k-comment-3 { color: darkblue }
.k-operative   { color:darkred; font-weight: bold }
.k-applicative { color:darkred }
.k-boolean     { color:blue }
.k-keyword     { color:blue }
.k-number      { color:blue }
.k-character   { color:blue }
.k-string      { color:blue }
.k-special     { color:blue }
.k-inert       { color:blue }
.k-reference    { color: magenta; font-weight: bold }
.k-case { font-weight: bold }
.k-variable { font-weight: bold }
span.k-head:hover + span.k-tail {background-color:yellow}
span.k-head:hover {background-color:yellow}
")

;;
;; Abstract type for tokens. Styles (CSS classes) may
;; be attached to tokens.
;;
($provide! (token? make-token add-token-style!
            token-kind token-text token-style
            token-style-subset)

  ($define! (enc-token token? dec-token)
    (make-encapsulation-type))

  ($define! make-token
    ($lambda (kind text)
      (enc-token (vector kind text ()))))

  (for-each
    (wrap ($vau (symbol index) denv
      (set! denv symbol
        ($lambda (t) (vector-ref (dec-token t) index)))))
    ($quote* token-kind token-text token-style)
    (iota 3))

  ($define! add-token-style!
    ($lambda (token scope style)
      ;(format #t "add-token-style! ~w ~w ~w~%" token scope style)
      ($let ((v (dec-token token)))
        (vector-set! v 2 (cons (list scope style)
                               (vector-ref v 2))))))

  ($define! token-style-subset
    ($lambda (token key)
      (reverse
        (map cadr
          (filter ($lambda ((scope class)) (equal? scope key))
                  (token-style token)))))))

;;
;; Write tokens in HTML format.
;;
($provide! (write-token write-all-tokens)

  ($define! write-all-tokens
    ($lambda (ts)
      (for-each write-token ts)))

  ($define! write-token
    ($lambda (t)
      ($define! local-style
        (map style->class (token-style-subset t #:local)))
      (for-each
        ($lambda (x) (format #t "<span class=\"~a\">" x))
        (map style->class (token-style-subset t #:begin)))
      ($unless (null? local-style)
        (format #t "<span class=\"")
        (for-each ($lambda (x) (format #t " ~a" x)) local-style)
        (format #t "\">"))
      (html (token-text t))
      ($unless (null? local-style)
        (format #t "</span>"))
      (for-each
        ($lambda (x) (format #t "</span>"))
        (map style->class (token-style-subset t #:end)))))

  ($define! style->class
    ($lambda (style)
      (format "~a~a" css-class-prefix style)))

  ($define! html
    ($lambda (c)
      ($cond
        ((eq? c #\<) (write-string "&lt;"))
        ((eq? c #\>) (write-string "&gt;"))
        ((char? c)   (write-char c))
        ((string? c) (for-each html (string->list c)))))))

;;
;; Parse tokens.
;;

($provide! (read-token read-all-tokens)

  ($define! read-token
    ($lambda ()
      ($let* ((p (open-output-string))
              (kind (with-output-to-port p parse-token))
              (text (intern (get-output-string p))))
        ($cond
          ((eof-object? kind) kind)
          ((eq? kind #:special)
            ($match (assoc text special-tokens)
              ((#ignore . specific-kind)
                (make-token specific-kind text))
              (#ignore
                ($if ($and? (<=? 2 (string-length text))
                            (member? (string-ref text 1)
                              ($quote* #\x #\d #\o #\b #\e #\i)))
                  (make-token #:number text)
                  (make-token kind text)))))
          (#t
            (make-token kind text))))))

  ($define! special-tokens
    ($quote*
      ("#ignore" . #:ignore)
      ("#inert"  . #:inert)
      ("#t"      . #:boolean)
      ("#f"      . #:boolean)))

  ($define! interned-tokens
    (map
      list
      ($quote* "" " " "(" ")" "." "\n")))

  ($define! intern
    ($lambda (s)
      ($match (assoc s interned-tokens)
        (()  s)
        ((x) x))))

  ($define! read-all-tokens
    ($lambda ()
      ($define! t (read-token))
      ($if (eof-object? t)
        (list (make-token #:eof ""))
        (cons t (read-all-tokens)))))

  ($define! parse-token
    ($lambda ()
      ($define! c (read-char))
      ($unless (eof-object? c)
        (write-char c))
      ($cond
        ((eof-object? c)
          c)
        ((eq? c #\newline)
          #:newline)
        ((char-whitespace? c)
          (copy ($lambda (c)
            ($and? (not-newline? c) (char-whitespace? c))))
          #:whitespace)
        ((eq? c #\;)
          (copy not-newline?)
          #:line-comment)
        ((eq? c #\()
          #:left)
        ((eq? c #\))
          #:right)
        ((eq? c #\.)
          #:dot)
        ((eq? c #\#)
          (parse-hash-special))
        ((eq? c #\")
          (copy-quoted #\")
          #:string)
        ((char-digit? c)
          (copy token-tail?)
          #:number)
        ((memq? c ($quote* #\+ #\-))
          ($let ((k ($if (char-digit? (peek-char)) #:number #:symbol)))
            (copy token-tail?)
            k))
        (#t
          (copy-bar)
          #:symbol))))

  ($define! copy-bar
    ($lambda ()
      ($if (eq? (peek-char) #\|)
        ($sequence
          (write-char #\|)
          (read-char)
          (copy-quoted #\|))
        (copy token-tail?))))

  ($define! parse-hash-special
    ($lambda ()
      ($define! c (read-char))
      ($when (char? c)
        (write-char c))
      ($cond
        ((eof-object? c)
          #:unknown)
        ((eq? c #\:)
          (copy-bar)
          #:keyword)
        ((eq? c #\\)
          (parse-character-literal)
          #:character)
        ((eq? c #\!)
          (copy not-newline?)
          #:line-comment)
        ((eq? c #\;)
          #:datum-comment)
        ((eq? c #\|)
          (copy-block-comment c 0)
          #:block-comment)
        ((char-digit? c)
          (copy reference-tail?)
          #:reference)
        (#t
          (copy token-tail?)
          #:special))))

  ($define! parse-character-literal
    ($lambda ()
      ($define! c (read-char))
      (write-char c)
      ($when (char-alphabetic? c)
        (copy token-tail?))))

  ($define! copy
    ($lambda (accept?)
      ($let ((c (peek-char)))
        ($when ($and? (char? c) (accept? c))
          (read-char)
          (write-char c)
          (copy accept?)))))

  ($define! copy-block-comment
    ($lambda (prev-char nesting)
      ($define! this-char (read-char))
      ($define! chars (list prev-char this-char))
      (write-char this-char)
      ($cond
        ((eof-object? this-char)
          #inert)
        ((equal? chars ($quote* #\| #\#))
          ($if (zero? nesting)
            #inert
            (copy-block-comment this-char (- nesting 1))))
        ((equal? chars ($quote* #\# #\|))
          (copy-block-comment this-char (+ nesting 1)))
        (#t
          (copy-block-comment this-char nesting)))))

  ($define! copy-quoted
    ($lambda (qchar)
      ($let ((c (peek-char)))
        ($cond
          ((eof-object? c)
            #inert)
          ((eq? c qchar)
            (write-char c)
            (read-char))
          (#t
            (write-char c)
            (read-char)
            ($when (eq? c #\\)
              ($let ((d (read-char)))
                ($unless (eof-object? d)
                  (write-char d))))
            (copy-quoted qchar))))))


  ($define! extended-identifier-characters
    ($quote*
      #\! #\$ #\% #\& #\* #\+ #\- #\. #\/ #\:
      #\< #\= #\> #\? #\@ #\^ #\_ #\~))

  ($define! token-tail?
    ($lambda (c)
      ($or? (char-alphabetic? c)
            (char-digit? c)
            (memq? c extended-identifier-characters))))

  ($define! reference-tail?
    ($lambda (c)
      ($or? (char-digit? c) (memq? c ($quote* #\= #\#)))))

  ($define! backslash?
    ($lambda (c)
      (eq? c #\\))))

  ($define! newline?
    ($lambda (c) (eq? c #\newline)))

  ($define! not-newline?
    ($lambda (c) (not? (eq? c #\newline))))

;;
;; Style comments and atomic values.
;;

($provide! (style-unstructured)

  ($define! string-prefix?
    ($lambda (pfx str)
      ($let ((n (string-length pfx))
             (m (string-length str)))
        ($and? (<=? n m)
               (string=? pfx (substring str 0 n))))))

  ($define! style-unstructured
    ($lambda (t)
      ($define! k (token-kind t))
      ($cond
        ((eq? k #:line-comment)
          (style-line-comment t))
        ((eq? k #:block-comment)
          (add-token-style! t #:local "comment-1"))
        ((member? k ($quote* #:string #:number #:boolean #:character
                             #:keyword #:special #:ignore #:inert
                             #:reference))
          (add-token-style! t #:local (keyword->string k))))))

  ($define! style-line-comment
    ($lambda (t)
      ($define! text (token-text t))
      ($define! style
        ($cond
          ((string-prefix? ";;;" text) "comment-3")
          ((string-prefix? ";;" text)  "comment-2")
          (#t                          "comment-1")))
      (add-token-style! t #:local style))))

($provide! (for-each-structure)

  ($define! ignored-tokens
    ($quote* #:line-comment #:block-comment
             #:whitespace #:newline #:reference))

  ($define! for-each-structure
    ($lambda (f ts)
      ($define! (val tail) (parse-structure ts))
      (apply f (list val))
      ($unless (eq? (token-kind (car tail)) #:eof)
        (for-each-structure f tail))))

  ($define! parse-structure
    ($lambda ((t . ts))
      ($cond
        ((eq? (token-kind t) #:eof)
          (list t (cons t ts)))
        ((eq? (token-kind t) #:left)
          (parse-list t () ts))
        ((eq? (token-kind t) #:datum-comment)
          ($define! (#ignore tail) (parse-structure ts))
          (parse-structure tail))
        ((member? (token-kind t) ignored-tokens)
          (parse-structure ts))
        (#t
          (list t ts)))))

  ($define! parse-list
    ($lambda (t-left acc ts)
      ($define! k (token-kind (car ts)))
      ($cond
        ((eq? k #:left)
          ($define! (val tail) (parse-list (car ts) () (cdr ts)))
          (parse-list t-left (cons val acc) tail))
        ((eq? k #:right)
          (list (list t-left (reverse acc) (car ts)) (cdr ts)))
        ((eq? k #:eof)
          (list (list t-left (reverse acc) (car ts)) ts))
        ((member? k ignored-tokens)
          (parse-list t-left acc (cdr ts)))
        (#t
          ($define! (val tail) (parse-structure ts))
          (parse-list t-left (cons val acc) tail))))))

;;
;; Style list structures.
;;

($provide! (style-structure)

  ($define! program-env
    (make-kernel-standard-environment))

  ($define! style-structures
    ($lambda (xs nesting)
      (for-each ($lambda (x) (style-structure x nesting)) xs)))

  ($define! style-structure
    ($case-lambda
      (((t-left (f . xs) t-right) nesting)
        ($define! style-default
          ($lambda ()
            (style-structures (cons f xs) (+ 1 nesting))))
        ($cond
          (($and? (token? f) (eq? (token-kind f) #:symbol))
            (style-head-tail
              (list t-left f)
              (append xs (list t-right)))
            ($define! s (string->symbol (token-text f)))
            ($if ((wrap $binds?) program-env s)
              ($let ((val (eval s program-env)))
                ($cond
                  ((applicative? val)
                    (add-token-style! f #:local "applicative")
                    (style-structures xs (+ 1 nesting)))
                  ((operative? val)
                    ($unless (style-operative-combination s f xs nesting)
                      (add-token-style! f #:local "operative")
                      (style-structures xs (+ 1 nesting))))
                  (#t
                    (style-default))))
              (style-default)))
          (#t
            (style-default))))
      (#ignore
        #inert)))

  ($define! style-operative-combination
    ($lambda (symbol f xs nesting)
      ;(format #t "OPERATIVE: ~w ~w ~w~%" symbol xs nesting)
      ($match (assoc symbol operative-combination-patterns)
        ((#ignore . pats)
          (add-token-style! f #:local "operative")
          (style-by-pattern (cons #ignore pats) (cons f xs) nesting)
          #t)
        (#ignore
          #f))))

  ($define! operative-combination-patterns
    ($quote*
      ($lambda #:ptree . #ignore)
      ($vau #:ptree #:ptree . #ignore)
      ($define! #:ptree . #ignore)
      ($provide! #:ptree . #ignore)
      ($set! #ignore #:ptree #ignore)
      ($let #:bindings . #ignore)
      ($let* #:bindings . #ignore)
      ($letrec #:bindings . #ignore)
      ($letrec* #:bindings . #ignore)
      ($let-redirect #ignore #:bindings . #ignore)
      ($let-safe #:bindings . #ignore)
      ($import! #ignore . #:ptree)
      ($binds? #ignore . #:ptree)
      ($bindings->environment . #:bindings)
      ($case-lambda . #:bindings)
      ($match #ignore . #:bindings)
      ($provide-library! #:quoted #:ptree . #ignore)
      ($quote . "quoted")
      ($quote* . "quoted")))

  ($define! style-by-pattern
    ($case-lambda
     (((pat . pats) (str . strs) nesting)
        ($cond
          ((ignore? pat)
            (style-structure str (+ 1 nesting)))
          ((eq? pat #:ptree)
            (style-ptree str nesting))
          ((eq? pat #:bindings)
            (style-bindings str nesting)))
        ($cond
          ((null? pats)
            #inert)
          ((ignore? pats)
            (style-structures strs (+ 1 nesting)))
          ((eq? pats #:ptree)
            (for-each ($lambda (x) (style-ptree x (+ 1 nesting))) strs))
          ((eq? pats #:bindings)
            (style-bindings-tail strs nesting))
          ((pair? pats)
            (style-by-pattern pats strs nesting))))
     (#ignore
       #inert)))

  ($define! style-ptree
    ($lambda (ptree nesting)
      ($cond
        ((token? ptree)
          ($cond
            ((equal? (token-kind ptree) #:symbol)
              (add-token-style! ptree #:local "variable"))))
        ((pair? ptree)
          ($define! (l-token items r-token) ptree)
          (for-each
            ($lambda (i) (style-ptree i (+ 1 nesting)))
            items)))))

  ($define! style-bindings
    ($case-lambda
      (((t0-left bs t0-right) nesting)
        (style-bindings-tail bs nesting))
      (#ignore
        #inert)))

  ($define! style-bindings-tail
    ($lambda (bs nesting)
      (for-each
        ($case-lambda
          (((t1-left (p . rest) t1-right))
            (add-token-style! t1-left #:local "case")
            (add-token-style! t1-right #:local "case")
            (style-ptree p (+ 1 nesting))
            (style-structures rest (+ 1 nesting)))
          (#ignore
            #inert))
        bs)))

  ($define! style-head-tail
    ($lambda (head tail)
      (style-block "head" head)
      (style-block "tail" tail)))

  ($define! first-last
    ($lambda (t)
      ($cond
        ((token? t) (list t t))
        ((pair? t)  (list (car t) (caddr t))))))

  ($define! style-block
    ($lambda (style structures)
      ($define! (l r)
        ($match structures
          ((t) (first-last t))
          ((t . ts) (list (car (first-last t)) (cadr (first-last (last ts)))))))
      ($if (eq? l r)
        (add-token-style! l #:local style)
        ($sequence
          (add-token-style! l #:begin style)
          (add-token-style! r #:end style)))))

  ($define! last
    ($case-lambda
      (((x)) x)
      (((x . xs)) (last xs)))))

;;
;; Main program.
;;

($define! colorize
  ($lambda ()
    ($define! ts (read-all-tokens))
    (for-each style-unstructured ts)
    (for-each-structure ($lambda (s) (style-structure s 0)) ts)
    (write-all-tokens ts)
    (flush-output-port)))

($match (get-script-arguments)
  ((#ignore mode)
    ($cond
      ((equal? mode "css")
        (write-string example-css))
      ((equal? mode "pre")
        (format #t "<pre>\n")
        (colorize)
        (format #t "\n</pre>\n"))
      (#t
        (write-string usage-msg stderr)
        (exit 1))))
  (#ignore
    (format #t "<html><head>\n")
    (format #t "<meta charset=\"utf-8\">\n")
    (format #t "<style>\n")
    (write-string example-css)
    (format #t "</style></head><body><pre>\n")
    (colorize)
    (format #t "\n</pre></body></html>\n")))
