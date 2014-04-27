;;;
;;; rosettacode-fce.k
;;;
;;; A solution to http://rosettacode.org/wiki/First_class_environments.
;;; Adapted from PicoLisp solution that can be also found on the web page.
;;;

($define! print-column
  ($lambda (n)
    ($let ((s (number->string n)))
      (display (make-string (- 4 (string-length s)) #\space))
      (display s))))

($let ((envs  (map ($lambda (n) ($define! cnt 0) (get-current-environment))
                   (list 1 2 3 4 5 6 7 8 9 10 11 12))) ; could use list-tabulate
       ($lame ($vau body #ignore
                ($lambda (e) (eval (cons $sequence body) e)))))
  #1=($unless (apply and? (map ($lame (=? n 1)) envs))
    (for-each
      ($lame
        (print-column n)
        ($unless (=? n 1)
          ($define! cnt (+ 1 cnt))
          ($define! n   ($let (((q r) (div-and-mod n 2)))
                          ($if (zero? r) q (+ (* 3 n) 1))))))
      envs)
    (newline)
    #1#)
  (display (make-string 48 #\=))
  (newline)
  (for-each ($lame (print-column cnt)) envs)
  (newline))
