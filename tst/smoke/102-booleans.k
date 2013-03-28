;; test basic boolean operations
(list
  (not? #f)
  (not? #t)
  ($and? #f #f)
  ($and? #f #t)
  ($and? #t #t)
  ($or? #f #f)
  ($or? #f #t)
  ($or? #t #t))
