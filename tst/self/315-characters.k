;;;
;;; 315-characters.k
;;;
;;; Test character features.
;;;

;; char-alphabetic? char-whitespace?

($define! $test-char-predicate
  ($vau (pred ref . xs) denv
    (for-each
      ($lambda (x)
        ($define! res (protect-eval (list pred x) denv))
        ($if (equal? res (list "return" ref))
          (pass)
          (fail-with-report "character-predicate"
            (list pred x) res ref)))
      xs)))

;; ASCII range

($test-char-predicate char-alphabetic? #t
  #\a #\z #\A #\Z)

($test-char-predicate char-alphabetic? #f
  #\@ #\$ #\newline #\space)

($test-char-predicate char-whitespace? #t
  #\newline #\space #\x09)

($test-char-predicate char-whitespace? #f
  #\x08 ; backspace is not whitespace
  #\@ #\$ #\a #\z #\A #\Z #\0 #\9)

;; unicode

($test-char-predicate char-alphabetic? #t
  #\Â #\β #\щ)

($test-char-predicate char-alphabetic? #f
  #\⊕ #\☺ #\₀)

($test-char-predicate char-whitespace? #t
  #\x1680
  #\x2000 #\x2001 #\x2005 #\x2009 #\x200A
  #\x2028 #\x2029 #\x202F #\x205F #\x3000)

($test-char-predicate char-whitespace? #f
  #\x1679 #\x1681
  #\x1FFF #\x200B
  #\x2027 #\x202A #\x202E #\x2030 #\x205E #\x2060 #\x2FFF #\x3001)

;; char-digit?

($test-char-predicate char-digit? #t
  #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)

($test-char-predicate char-digit? #f
  #\a #\z #\A #\Z #\/ #\:)

(summary)
