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
