;;;
;;; 302-datum-labels.k
;;;
;;; Test reading and printing shared structures
;;; (SRFI-38 alias datum lables in R7RS)
;;;

($define! $r
  ($vau (ext int . rest) denv
    ($define! read-result
      (protect-call ($lambda () (read (open-input-string ext)))))
    ($if (equal? read-result (list "return" int))
      ($sequence
        (pass)
        ($when (pair? rest)
          ($let (((chk) rest)
                 ((#ignore value) read-result))
            ($if ((eval chk denv) value)
              (pass)
              (fail-with-report "read/check" ext value chk)))))
      (fail-with-report "read/equal?" ext read-result int))))

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

;; canonical representation
;;
($rw "#0=(#0# . #0#)" #0=(#0# . #0#))
($rw "#0=(#0# #0#)" #0=(#0# #0#))
($rw "(x #0=(#0# #0#) y)" (x #0=(#0# #0#) y))
($rw "(x #0=(#0# . #0#) y)" (x #0=(#0# . #0#) y))

;; degenerate representation
;;
($r "#0=1" 1)
($r "#0=#1=2" 2)
($r "#99=(1 . #99#)" #0=(1 . #0#))
($r "#0=#1=(#0# #1#)"
    #0=(#0# #0#)
    ($lambda (x)
      ($and? (=? (length x) 2)
             (eq? x (car x) (cadr x)))))

(summary)
