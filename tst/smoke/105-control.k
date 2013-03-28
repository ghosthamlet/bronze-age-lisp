;; test basic control features
(list
  (inert? #inert) (inert? #ignore)
  ($if (eq? 0 1) 2 3) ($if (eq? 4 4) 5 6)
  ($sequence) ($sequence 7) ($sequence 8 9)
  ($cond (#f 10) (#t 11) (#t 12))
  ($when #t 13) ($when #f 14)       ; FAIL, $when not robust
  ($unless #t 15) ($unless #f 16))  ; FAIL, $unless not robust
