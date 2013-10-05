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
    result))

($define-private-wrapvau! general-map x env
  ($check-map-arguments map x)
  ($define! (appv . lss) x)
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
  ($check-map-arguments for-each x)
  (apply map x env)
  #inert)

($define-private-vau! $check-map-arguments (s x) denv
  ($match (eval x denv)
    ((appv ls1 . lss)
      ($unless (applicative? appv)
        (apply-continuation error-continuation
          (make-error-object "Invalid argument." appv s))))
    (x
      (apply-continuation error-continuation
        (make-error-object "Invalid argument structure." x s)))))
