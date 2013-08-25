;;;
;;; 303-invalid-syntax.k
;;;
;;; Test error handling in the reader.
;;;

($define! $e
  ($vau (ext . err) denv
    ($define! read-result
      (protect-call ($lambda () (read (open-input-string ext)))))
    ($cond
      ((null? err)
        ($if (equal? (car read-result) "error")
          (pass)
          (fail-with-report "read" ext read-result "error")))
      ((pair? err)
        ($if ($and? (equal? (car read-result) "error")
                    (equal? (cadr read-result) (eval (car err) denv))
                    (equal? (caddr read-result) (eval (cadr err) denv)))
          (pass)
          (fail-with-report "read" ext read-result (list* "error" err))))
      (#t
        (error "$e" (list* ext err))))))

($define! *eof-object*
  (with-input-from-string "" read-char))

;; invalid special tokens and character names
;;
($e "#blabla")
($e "#\\blabla")

;; invalid unicode code points specified by hexadecimal constant
;;
($let ((m "Not a valid unicode code point"))
  ($e "#\\xD800" m 55296)
  ($e "#\\xD801" m 55297)
  ($e "#\\xDABC" m 55996)
  ($e "#\\xDFFE" m 57342)
  ($e "#\\xDFFF" m 57343)
  ($e "#\\xFFFE" m 65534))

($e "#\\xFFFFFFFF")

;; invalid keywords
;;
($e "#:(")
($e "#:)")
($e "#:#")

;; invalid lists
;;
($e "(")
($e ")")
($e "(()")
($e "(1 2 . )")
($e "(1 2 . 3 4)")
($e "(. 1)")

;; invalid comments
;;
($let ((m "unterminated #|block|# comment"))
  ($e "#|aaaaa" m (list 1 8))
  ($e "#|" m (list 1 3))
  ($e "#| #| |#" m (list 1 9)))
($e "#| |# |#")

;; invalid datum labels
;;
($e "#0=" 1)

($let ((m "undefined S-expression label"))
  ($e "#0#" m (list 0 1 4))
  ($e "#1=(#0#)" m (list 0 1 8))
  ($e "#0=(#1#)" m (list 1 1 8)))

($let ((m "invalid S-expression label"))
  ($e "(#0)" m (list 0 #\) 1 5))
  ($e "#0" m (list 0 *eof-object* 1 3))
  ($e "#123a" m (list 123 #\a 1 6)))

(summary)
