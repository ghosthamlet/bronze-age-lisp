;;;
;;; lists.k
;;;
;;; Built-in list applicatives.
;;;

($provide! ()
  ($define! $bind!
    ($vau (symbol label rel) denv
      (bind-ground! symbol
        (make-bounded-applicative
          (list 2 2)
          (list label)
          (list symbol (make-nonlisp-value rel))))))

  ($bind! assoc "app_assoc" "rn_equal")
  ($bind! assq "app_assoc" "rn_eq")
  ($bind! member? "app_member" "rn_equal")
  ($bind! memq? "app_member" "rn_eq"))

;;
;; Implementation of (append ...), based on Kernel Report.
;; Two-argument applicative call (append X Y) is handled
;; in lists.asm.
;;
($defun-privates!
  (general-append lss
    ($if (null? lss)
     ()
     ($sequence
       ($define! (#ignore #ignore a c) (get-list-metrics lss))
       ($if (>? c 0)
         ($let1 cycle (append-aux c (list-tail lss a) ())
           ($when (pair? cycle)
             (encycle! cycle 0 (length cycle)))
           (append-aux a lss cycle))
         (append-aux (- a 1) lss (list-ref lss (- a 1)))))))
  (append-aux (k lss tail) ; prepend k elmts of lss onto tail
    ($if (>? k 0)
      (append (car lss)
              (append-aux (- k 1) (cdr lss) tail))
      tail)))
