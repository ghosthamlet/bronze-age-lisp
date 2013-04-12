;;;
;;; continuations.k
;;;
;;; Kernel continuation features (lisp part).
;;;

($define-ground-wrapvau! call/cc (appv) env
  ($let/cc cont
    (apply appv (list cont) env)))
