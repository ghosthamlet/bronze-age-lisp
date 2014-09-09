;;;
;;; 319-read-time-evaluation.k
;;;
;;; Test read time evaluation syntax (#.X).
;;;


($define! $r
  ($vau (ext int) #ignore
    ($define! read-result
      (protect-call ($lambda () (read (open-input-string ext)))))
    ($if (equal? read-result (list "return" int))
      (pass)
      (fail-with-report "read" ext read-result int))))

(with-read-time-evaluation-environment
  (make-kernel-standard-environment)
  ($lambda ()
    ($r "#.1" 1)
    ($r "#.#t" #t)
    ($r "#.(+ 1 2)" 3)
    ($r "#.(list* 1 2 3)" (1 2 . 3))
    ($set! (get-read-time-evaluation-environment) some-symbol 42)
    ($r "#.some-symbol" 42)
    ($r "#.($define! some-symbol 43)" #inert)
    ($r "#.some-symbol" 43)
    ($r "#.#;1 2 3" 2)
    ($r "#;4 #.5 6" 5)))

(summary)
