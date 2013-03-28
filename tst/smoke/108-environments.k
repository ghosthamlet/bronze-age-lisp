;; basic operations on environments
($sequence
  ($define! v 1)
  ($define! w 2)
  ($set! (get-current-environment) v 3)
  (list v w))
