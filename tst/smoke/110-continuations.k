;; basic continuation operations
($sequence
  ($define! guards
    (list
      (list
        error-continuation
        ($lambda (v divert)
          (divert 99 (error-object-message v))))))
  ($define! succeed
    ($lambda () 42))
  ($define! fail
    ($lambda () (error "blabla error message")))
  (list
    (continuation? root-continuation)
    (continuation? error-continuation)
    (continuation? ($lambda () ()))
    (guard-dynamic-extent () succeed ())
    (guard-dynamic-extent () succeed guards)
    (guard-dynamic-extent () fail guards)))
