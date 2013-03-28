;;;
;;; assembly.k
;;;
;;; Printing programs in NASM-compatible assembly language.
;;;

;;
;; (asm-identifier S1 ... Sn) => STRING
;;
;; Concatenates S1 ... Sn to make a valid assembly language
;; identifier. Converts the arguments to strings and replaces
;; invalid characters, if necessary.
;;
($provide! (asm-identifier)
  ($define! subst-alist
    ($quote*
      (#\! #\B) (#\$ #\S) (#\? #\P) (#\* #\X)
      (#\. #\_) (#\- #\_) (#\= #\E) (#\+ #\C)
      (#\( #\_) (#\) #\_) (#\/ #\_) (#\< #\L) (#\> #\G)
      (#\space #\_)
      (#\newline #\_)))
  ($define! asm-char
    ($lambda (x)
      ($let ((y (assoc x subst-alist)))
        ($if (null? y) x (cadr y)))))
  ($define! asm-identifier
    ($lambda args
      (list->string
        (map asm-char
          (string->list (apply string-append* args)))))))

;;
;; (asm S1 S2...)
;;
;; Prints one assembler line, separating arguments with spaces.
;;
($define! asm
  ($lambda terms
    (for-each ($lambda (t) (display #\space) (display t)) terms)
    (newline)))

;;
;; (asm-include FILE)
;;
;; Prints assembler command to include FILE.
;;
($define! asm-include
  ($lambda (file-path)
    (display "%include ")
    (write file-path)
    (newline)))

;;
;; (asm-comment S1 S2...)
;;
($define! asm-comment
  ($lambda terms
    (display ";;")
    (for-each ($lambda (t) (display " ") (display t)) terms)
    (newline)))

;;
;; (asm-label L)
;;
($define! asm-label
  ($lambda (label)
    (display (string-append* label ":"))
    (newline)))

;;
;; (asm-utf8 STRING)
;;
;; Prints definition of UTF-8 encoding of STRING.
;;
($provide! (asm-utf8)
  ($define! char->utf8
    ($lambda (chr)
      ($define! cp (char->integer chr))
      ($if (<=? 0 cp 127)
        (list cp)
        (error "TODO: unicode"))))
  ($define! asm-utf8
    ($lambda (str)
      ($let ((b (apply append (map char->utf8 (string->list str)))))
        ($unless (null? b)
          (display " db ")
          (for-each ($lambda (p) (write p) (display #\,)) b))))))
