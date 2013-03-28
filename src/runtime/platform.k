;;;
;;; platform.k
;;;
;;; Linux-dependent features.
;;;

($when ($configured stdio)
  ($define! $bind-port!
    ($vau (symbol filedes input) #ignore
       (bind-ground! symbol
         (make-standard-port
           ($if input bin-in-header* bin-out-header*)
           filedes
           "linux_close"
           ($if input "linux_read" "linux_write")
           "linux_nop"))))
  ($bind-port! stdin 0 #t)
  ($bind-port! stdout 1 #f)
  ($bind-port! stderr 2 #f))
