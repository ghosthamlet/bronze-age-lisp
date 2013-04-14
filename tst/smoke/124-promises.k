;;; test promises
(list
  ;; demo from Kernel Report page 131
  ($let ()
    ($provide! (get-count p)
      ($define! count 5)
      ($define! get-count ($lambda () count))
      ($define! p
        ($let ((self (get-current-environment)))
          ($lazy
            ($if (<=? count 0)
                 count
                 ($sequence
                    ($set! self count (- count 1))
                    (force p)
                    ($set! self count (+ count 2))
                    count))))))
    (list (get-count)
          (force p)
          (get-count)))
  ;; demo from Kernel Report page 132
  ($let ((port (open-output-string)))
    ($define! p1 ($lazy (display "*" port)))
    ($define! p2 ($lazy p1))
    (force p2)
    ($define! snapshot1 (get-output-string port))
    (force p1)
    ($define! snapshot2 (get-output-string port))
    (list snapshot1 snapshot2)))
