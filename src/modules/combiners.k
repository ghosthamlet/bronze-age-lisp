;;;
;;; combiners.k
;;;
;;; Extensions.
;;;

($define-private-lambda! case-lambda-message (c)
  (list (car c) ($quote |...|)))

($define-private-vau! $case-lambda-failure (x . clauses) denv
  (apply error
    (list* "Match failure ($case-lambda)"
           (eval x denv)
           (map case-lambda-message clauses))))

($bind-private! $match-unsafe
  (make-primitive-operative "primop_Smatch_unsafe"))

($define-ground-vau! $case-lambda clauses denv
  ($unless (apply pair? clauses)
    (error "Invalid parameter tree(s) ($case-lambda)" clauses))
  ($unless (apply formal-parameter-tree? (map car clauses))
    (apply error
      (list* "Invalid parameter tree(s) ($case-lambda)"
              (map case-lambda-message clauses))))
  ($define! clauses
    (append (copy-es-immutable clauses)
            (list (list ($quote x)
                        (list* $case-lambda-failure ($quote x) clauses)))))
  ($lambda x
    (eval (list* $match-unsafe x clauses)
          denv)))
