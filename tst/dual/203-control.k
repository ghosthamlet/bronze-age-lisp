;; Check ($cond ...) against derivation from $vau
;; from Kernel Report section 5.6.1
;;
($check $cond
  ($vau clauses env
    ($define! aux
      ($lambda ((test . body) . clauses)
        ($if (eval test env)
             (apply (wrap $sequence) body env)
             (apply (wrap $cond) clauses env))))
    ($if (null? clauses)
      #inert
      (apply aux clauses)))
  #inert
  ((operative? $cond)
   ($cond)
   ($cond #t #f)
   ($cond (#t 1) (#f blabla))
   ($cond (#f quaqua) (#t 4))
   ($cond ((not? #t) (not? #f)) ((not? #f) (not? #t)))))

;; Check (map ...) against derivation from Kernel Report section 5.9.1
;;

($check map
  (wrap ($vau (appv . lss) env
    ($define! acc
      ($lambda (input (k1 k2) base-result head tail sum)
        ($define! aux
          ($lambda (input count)
            ($if (=? count 0)
                 base-result
                 (sum (head input)
                      (aux (tail input) (- count 1))))))
        (aux input (+ k1 k2))))
    ($define! enlist
      ($lambda (input ms head tail)
        ($define! result (acc input ms () head tail cons))
        (apply encycle! (list* result ms))
        result))
    ($define! mss (cddr (get-list-metrics lss)))
    ($define! cars ($lambda (lss) (enlist lss mss caar cdr)))
    ($define! cdrs ($lambda (lss) (enlist lss mss cdar cdr)))
    ($define! result-metrics
      (acc lss mss (cddr (get-list-metrics (car lss)))
          ($lambda (lss) (cddr (get-list-metrics (car lss))))
          cdr
          ($lambda ((j1 j2) (k1 k2))
            (list (max j1 k1)
                  ($cond ((=? j2 0) k2)
                         ((=? k2 0) j2)
                         (#t (lcm j2 k2)))))))
    (enlist lss
      result-metrics
      ($lambda (lss) (apply appv (cars lss) env))
      cdrs)))
  #inert
  ((applicative? map)
   (map)
   (map list ())
   (map list (list "" " " "a"))
   (map abs (list 1 -2 -3 4 -5))
   ($let ((ls (list 1 2 3 4 5)))
     (encycle! ls 2 3)
     (map ($lambda (x) (+ x 1)) ls))
   (map car ($lambda () ()))
   ;; test passing dynamic environment to the combiner
   ($let* ((f (wrap ($vau (x) e (list x ($binds? e f) ($binds? e g) ($binds? e h)))))
           (g (list 1)))
     (map f g))
   ($let* ((f (wrap ($vau (x) e (list x ($binds? e f) ($binds? e g) ($binds? e h)))))
           (g ($lambda () (list 1))))
     (map f (g)))
   ($let* ((f (wrap ($vau (x y) e (list x y ($binds? e f) ($binds? e g)))))
           (g ($lambda (x) (list 3 x))))
     (map f (g 1) (g 2)))))
