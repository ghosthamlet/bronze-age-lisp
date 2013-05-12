;; basic operations on environments
($sequence
  ($define! v 1)
  ($define! w 2)
  ($set! (get-current-environment) v 3)
  (list v w)
  ($remote-eval
    ($sequence
      ($define! u 20)
      u)
    (make-environment
      (make-kernel-standard-environment)
      (make-kernel-standard-environment)
      (make-kernel-standard-environment))))
