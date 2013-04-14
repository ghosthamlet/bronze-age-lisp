;;;
;;; iterations.k
;;;
;;; Implementation of (map ...) and (for-each ...), lisp part.
;;;
;;; Reference implementation from Kernel Report.
;;;

($defun-privates!
  (map-acc (input (k1 k2) base-result head tail sum)
    ($define! aux
      ($lambda (input count)
        ($if (=? count 0)
             base-result
             (sum (head input)
                  (aux (tail input) (- count 1))))))
    (aux input (+ k1 k2)))
  (map-enlist (input ms head tail)
    ($define! result (map-acc input ms () head tail cons))
    (apply encycle! (list* result ms))
    result)

  ;; TEMPFIX: implementation of max and lcm

  (naive-lcm (x0 y0 x y)
    ($cond
      ((=? x y) x)
      ((<? x y) (naive-lcm x0 y0 (+ x x0) y))
      (#t (naive-lcm x0 y0 x (+ y y0)))))
)

($define-ground-lambda! lcm (x y)
  ($when ($or? (<=? x 0) (<=? y 0))
    (error "lcm - negative and zero arguments not supported yet"))
  (naive-lcm x y x y))

($define-private-wrapvau! general-map (appv . lss) env
  ($define! mss (cddr (get-list-metrics lss)))
  ($define! cars ($lambda (lss) (map-enlist lss mss caar cdr)))
  ($define! cdrs ($lambda (lss) (map-enlist lss mss cdar cdr)))
  ($define! result-metrics
    (map-acc
      lss
      mss
      (cddr (get-list-metrics (car lss)))
      ($lambda (lssx) (cddr (get-list-metrics (car lssx))))
      cdr
      ($lambda ((j1 j2) (k1 k2))
        (list (max j1 k1)
              ($cond ((=? j2 0) k2)
                     ((=? k2 0) j2)
                     (#t (lcm j2 k2)))))))
  (map-enlist lss
          result-metrics
          ($lambda (lss) (apply appv (cars lss) env))
          cdrs))

($define-private-wrapvau! general-for-each x env
  (apply map x env)
  #inert)
