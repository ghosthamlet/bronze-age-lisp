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
