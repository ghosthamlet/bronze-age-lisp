;;;
;;; numbers.k
;;;
;;; Implementation of arithmetic features, lisp part.
;;;

($define-ground-lambda! abs (x)
  ($if (negative? x) (negate x) x))
