;; Check (car ...) and (cdr ...) against the derivations
;; from Kernel Report section 5.3.1
;;
($check car
  ($lambda ((x . #ignore)) x)
  #inert
  ((applicative? car)
   (operative? (unwrap car))
   (car (list 1 2))
   (car ())
   ((unwrap car))
   ((unwrap car) 1)
   ((unwrap car) 1 2)))

($check cdr
  ($lambda ((#ignore . x)) x)
  #inert
  ((applicative? cdr)
   (operative? (unwrap cdr))
   (cdr (list 1 2))
   (cdr ())
   ((unwrap cdr))
   ((unwrap cdr) 1)
   ((unwrap cdr) 1 2)))

;; Check (list ...) against the two possible derivations
;; from Kernel Report section 5.2.1
;;
($check list
  (wrap ($vau x #ignore x))
  #inert
  ((applicative? list)
   (list)
   (list . 0)
   (list 1)
   (list 2 3)
   (list 4 5 6)
   (list 7 8 9 10)))
($check list
  ($lambda x x)
  #inert
  ((applicative? list)
   (list)
   (list . 0)
   (list 1)
   (list 2 3)
   (list 4 5 6)
   (list 7 8 9 10)))

;; Check (list* ...) against the two possible derivations
;; from Kernel Report section 5.2.2
;;
($check list*
  (wrap ($vau args #ignore
          ($sequence
            ($define! aux
              (wrap ($vau ((head . tail)) #ignore
                      ($if (null? tail)
                           head
                           (cons head (aux tail))))))
            (aux args))))
  #inert
  ((applicative? list*)
   (list*)
   (list* . 0)
   (list* 1)
   (list* 2 3)
   (list* 4 5 6)
   (list* 7 8 9 10)))

($check list*
  ($lambda (head . tail)
    ($if (null? tail)
      head
      (cons head (apply list* tail))))
  #inert
  ((applicative? list*)
   (list*)
   (list* . 0)
   (list* 1)
   (list* 2 3)
   (list* 4 5 6)
   (list* 7 8 9 10)))

;; Check (get-list-metrics ...) against derivation
;; from Kernel Report section 5.7.1
;;
($check get-list-metrics
  ($lambda (ls)
    ($define! aux
      ($lambda (kth k nth n)
        ($if (>=? k n)
             ($if (pair? (cdr nth))
                  (aux ls 0 (cdr nth) (+ n 1))
                  (list (+ n 1)
                        ($if (null? (cdr nth)) 1 0)
                        (+ n 1)
                        0))
             ($if (eq? kth nth)
                  (list n 0 k (- n k))
                  (aux (cdr kth) (+ k 1) nth n)))))
    ($if (pair? ls)
         (aux ls 0 ls 0)
         (list 0 ($if (null? ls) 1 0) 0 0)))
  #inert
  ((applicative? get-list-metrics)
   (get-list-metrics #ignore)
   (get-list-metrics ())
   (get-list-metrics (cons 1 2))
   (get-list-metrics (list 1 2 3))
   (get-list-metrics (list* 1 2 3))))

;; Check (list-tail ...) against derivation
;; from Kernel Report section 5.7.2
;;
($check list-tail
  ($lambda (ls k)
    ($if (>? k 0)
         (list-tail (cdr ls) (- k 1))
         ls))
  #inert
  ((applicative? list-tail)
   (list-tail #f 0)
   (list-tail #f 1)
   (list-tail #f 0)
   (list-tail () 1)
   (list-tail (cons 1 2) 0)
   (list-tail (cons 1 2) 1)
   (list-tail (list 1 2 3) 2)))
