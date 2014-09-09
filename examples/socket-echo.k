;;;
;;; socket-echo.k
;;;
;;; Demonstration of low-level socket features.
;;;

($define! server
  ($lambda (port f)
    ($define! fd (socket PF_INET SOCK_STREAM 0))
    (setsockopt fd SOL_SOCKET SO_REUSEADDR (bytevector 1 0 0 0))
    (bind fd (make-struct-sockaddr #:ipv4 port INADDR_ANY))
    (listen fd 1)
    (format #t "Waiting for connection. Try 'telnet localhost ~w'.~%" port)
    ($define! server-loop
      ($lambda ()
        ($let ((c (accept fd)))
          (guard-dynamic-extent
            ()
            ($lambda ()
              (apply f (list (socket-textual-input-port c)
                             (socket-textual-output-port c))))
            (list (list error-continuation
                        ($lambda (#ignore d) (d)))))
          (close-socket c)
          (format #t "Waiting for next connection.~%")
          (server-loop))))
    (server-loop)))

($define! echo
  ($lambda (p q)
    ($let ((c (read-char p)))
      ($unless (eof-object? c)
        (write-char c q)
        (flush-output-port q)
        (echo p q)))))

(server 1234
  ($lambda (p q)
    (format q "*** Welcome to Bronze Age Echo Server! *** \r\n")
    (echo p q)))
