;;;
;;; numbers.k
;;;
;;; Implementation of arithmetic features, lisp part.
;;;

($define-ground-lambda! abs (x)
  ($if (negative? x) (negate x) x))

;;
;; printing numbers (incl. bigints)
;;
($defun-privates!
  (powers (x b w ws)
    ($if (<? x w)
      ws
      (powers x b (* b w) (cons w ws))))
  (slow-div (a b q)
    ($if (>=? a b)
      (slow-div (- a b) b (+ q 1))
      (cons a q)))
  (print-digits (a (w . ws) p)
    ($let (((r . d) (slow-div a w 0)))
      (write-char (char-digit d) p)
      ($when (>? w 1) (print-digits r ws p))))
  (char-digit (d)
    (integer->char (+ ($if (<? d 10) #x30 #x37) d)))
  (print-positive-integer (n b p)
    (print-digits n (powers n b 1 ()) p))
  (print-integer (n b p)
    ($cond
      ((positive? n)
        (print-positive-integer n b p))
      ((negative? n)
        (write-char #\- p)
        (print-positive-integer (negate n) b p))
      (#t
        (write-char #\0 p)))))

($define-ground-lambda! number->string (x . r)
  ($cond
    ((eq? x #e+infinity) "#e+infinity")
    ((eq? x #e-infinity) "#e-infinity")
    ((integer? x)
       ($let ((b
         ($cond
           ((null? r) 10)
           (($and? (pair? r)
                   (null? (cdr r))
                   (integer? (car r))
                   (<=? 2 (car r) 36))
              (car r))
           (#t
             (error "invalid radix for number->string")))))
         ($let ((p (open-output-string)))
           (print-integer x b p)
           (get-output-string p))))
    (#t (error "invalid argument for number->string"))))
