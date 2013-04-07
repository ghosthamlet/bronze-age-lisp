;; Check ($let* ...) against derivation from Kernel
;; Report section 6.7.4
;;
($check $let*
  ($vau (bindings . body) env
    (eval ($if (null? bindings)
               (list* $let bindings body)
               (list $let
                     (list (car bindings))
                     (list* $let* (cdr bindings) body)))
          env))
  #inert
  ((operative? $let*)
   ($let*)
   ($let* . 1)
   ($let* ())
   ($let* () . 2)
   ($let* () 3)
   ($let* (4) 5)
   ($let* (()) 6)
   ($let* ((x . 7)) 8)
   ($let* ((x 9)) x)
   ($let* ((x 10) (y 11) (z 12)) (list x y z))
   ($let* ((x 10) (y (+ x 1)) (z (+ y 2))) (list x y z))
   ($let* ((x ($binds? (get-current-environment) y))
           (y ($binds? (get-current-environment) x)))
          (list x y))))

;; Check ($letrec ...) against derivation from Kernel
;; Report section 6.7.5
;;
($check $letrec
  ($vau (bindings . body) env
    (eval (list* $let ()
                 (list $define!
                       (map car bindings)
                       (list* list (map cadr bindings)))
                 body)
           env))
  #inert
  ((operative? $letrec)
   ($letrec)
   ($letrec . 1)
   ($letrec ())
   ($letrec () . 2)
   ($letrec () 3)
   ($letrec (4) 5)
   ($letrec (()) 6)
   ($letrec ((x . 7)) 8)
   ($letrec ((x 9)) x)
   ($letrec ((x 10) (y 11) (z 12)) (list x y z))
   ($letrec
     ((f ($lambda (x)
           ($if (=? x 0) 1 (* x (f (- x 1)))))))
     (list (f 0) (f 1) (f 2) (f 3) (f 4) (f 5)))
   ($letrec ((f ($lambda (x) (g (+ x 1) (+ x 2))))
             (g ($lambda (x y) (list x y x y))))
            (list (f 10) (g 20)))))

