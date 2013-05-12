;; test of (gcd ...) and (lcm ...)
(list
  (gcd)
  (gcd 65 75)
  (gcd 3 #e+infinity 0 #e-infinity)
  ((unwrap gcd) 12 18 . #1=(42 60 . #1#))
  (lcm 3 6 9 2 5)
  (lcm 5 #e+infinity)
  ((unwrap lcm) 12 18 . #2=(42 60 . #2#)))
