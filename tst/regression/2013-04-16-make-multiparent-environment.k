;;;
;;; 2013-04-16-make-multiparent-environment.k
;;;
;;; BUG: (make-environment E[1] E[2] ... E[k]), k >= 2,
;;;      leaves unbalanced stack before invoking the current
;;;      continuation. May cause stack overflow and segmentation
;;;      fault.
;;;
;;; Found and fixed 2013-04-16.
;;;

($define! stress
  ($lambda (n f)
    ($define! aux ($lambda (k) ($when (<? 0 k) (f) (aux (- k 1)))))
    ($define! res
      (guard-dynamic-extent
        ()
        ($lambda () (aux n) (list "PASS"))
        (list
          (list root-continuation ($lambda (e d) (d "FAIL" e))))))
    (display " ")
    (display (car res))
    (flush-output-port)))

($define! e0 (make-environment))
(stress 10000000 ($lambda () (make-environment e0 e0)))
(stress 10000000 ($lambda () (make-environment e0 e0 e0)))
(newline)
