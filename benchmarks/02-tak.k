;;
;; 02-tak.k
;;
;; Tak (Takeuchi) function, a traditional lisp benchmark.
;; Adapted from [1], page 82.
;;
;;  [1] R. Gabriel: Performance and evaluation of Lisp systems.
;;      http://www.dreamsongs.com/NewFiles/Timrep.pdf.

($define! tak
  ($lambda (x y z)
    ($if (not? (<? y x))
      z
      (tak
        (tak (- x 1) y z)
        (tak (- y 1) z x)
        (tak (- z 1) x y)))))

(write
  (list
    (tak 18 12 6)
    (tak 18 12 6)
    (tak 18 12 6)
    (tak 18 12 6)))
