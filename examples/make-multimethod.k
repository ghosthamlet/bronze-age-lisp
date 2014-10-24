;;;
;;; make-multimethod.k
;;;
;;; Demonstrate how multiple dispatch could be implemented in Kernel Language.
;;;
;;; Dispatching starts with an user-defined dispatch function. The dispatch
;;; function computes an key into a mutable table of methods.
;;;
;;;   (make-multimethod DISPATCH-FUNCTION) => (MULTIMETHOD ADD!)
;;;
;;;   (DISPATCH-FUNCTION . ARGS) => KEY
;;;   (MULTIMETHOD . ARGS) => RESULT
;;;   (ADD! KEY METHOD) => #inert
;;;   (METHOD . ARGS) => RESULT
;;;
;;; The applicative make-multimethod returns the multimethod applicative
;;; and a mutator for adding new methods. Returning the mutator a first-class
;;; applicative is consistent with other Kernel Language features (e.g.
;;; make-keyed-dynamic-variable).
;;;
;;; The user-defined dispatch function is inspired by Clojure "defmulti" macro.
;;; However, there is no class hierarchy. If a method is not found, a default
;;; method associated with the keyword #:default is used instead.
;;;

($define! make-multimethod
  ($lambda (d)
    ($define! h
      (make-hash-table equal?))
    ($define! lookup
      ($lambda (x)
        ($if (hash-table-exists? h x)
          (hash-table-ref h x)
          (hash-table-ref h #:default))))
    (list (wrap ($vau x e (apply (lookup (apply d x e)) x e)))
          ($lambda (k f) (hash-table-set! h k f)))))

;; example of "single" dispatch

($provide! (perimeter)

  ($define! (perimeter add!)
    (make-multimethod ($lambda (k . #ignore) k)))

  (add! #:square    ($lambda (#ignore a) (* 4 a)))
  (add! #:rectangle ($lambda (#ignore a b) (* 2 (+ a b))))
  (add! #:triangle  ($lambda (#ignore a b c) (+ a b c))))

(format #t "example 1: ~w ~w ~w~%"
  (perimeter #:square 5)
  (perimeter #:rectangle 2 3)
  (perimeter #:triangle 4 5 6))

;; example of "multiple" dispatch

($provide! (sum)

  ($define! class
    ($lambda (x)
      ($cond ((string? x) #:string)
             ((number? x) #:number))))

  ($define! (sum add!)
    (make-multimethod ($lambda x (map class x))))

  (add! (list #:string #:string) string-append)
  (add! (list #:number #:number) +)
  (add! #:default                ($lambda x (cons ($quote invalid-sum) x))))

(format #t "example 2: ~w ~w ~w~%"
  (sum 1 2) (sum "1" "2") (sum 1 "b"))

;; example of double dispatch on an argument and the dynamic environment

($provide! ($def!)

  ($define! (def add!)
    (make-multimethod
      (wrap ($vau (mode name . #ignore) e
        (list ($if (binds? e name) ($quote update) ($quote create))
              mode)))))

  ($define! $def!
    (unwrap def))

  ($define! $case
    ($vau (state mode formals . eformal-body) denv
      (add! (list state mode)
            (wrap (eval (list* $vau (cons (cons #ignore formals) eformal-body))
                        denv)))))

  ($case create list (name value) denv
    (set! denv name (list (eval value denv))))

  ($case update list (name value) denv
    (set! denv name (cons (eval value denv) (eval name denv))))

  ($case create sum (name value) denv
     (set! denv name (eval value denv)))

  ($case update sum (name value) denv
     (set! denv name (+ (eval name denv) (eval value denv)))))

($let ()
  ($def! sum total 5)
  ($def! sum total 4)
  ($def! sum total 32)
  ($def! list items 5)
  ($def! list items 4)
  ($def! list items 32)
  (format #t "example 3: total = ~w, items = ~w~%" total items))
