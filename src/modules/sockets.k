;;;
;;; sockets.k
;;;
;;; Low-level interface to Linux networking system calls (lisp part).
;;;

(for-each
  ($lambda ((symbol label))
    (bind-private! symbol
      (make-bounded-applicative (list 1 1) (list label) ())))
  ($quote*
    (socket-fd "app_socket_fd.A1")
    (socket-raw-input-port "app_socket_raw_input_port.A1")
    (socket-raw-output-port "app_socket_raw_output_port.A1")))

;; Constants from usr/include/bits/socket.h and asm-generic/socket.h

($bind-ground! PF_UNIX      1)
($bind-ground! PF_INET      2)
($bind-ground! PF_INET6    10)
($bind-ground! SOCK_STREAM  1)
($bind-ground! SOCK_DGRAM   2)

($bind-ground! SOL_SOCKET   1)
($bind-ground! SO_REUSEADDR 2)

;; struct sockaddr constructors

($bind-ground! INADDR_ANY (list 0 0 0 0))
($bind-ground! INADDR_LOOPBACK (list 127 0 0 1))

($define-ground-lambda! make-struct-sockaddr (family . rest)
  (apply
    ($cond
      ((eq? family #:ipv4) struct-sockaddr-ipv4)
      ((eq? family #:ipv6) struct-sockaddr-ipv6)
      ((eq? family #:unix) struct-sockaddr-unix))
    rest))

($defun-privates!
  (struct-sockaddr-ipv4 (port (a1 a2 a3 a4))
    (bytevector PF_INET 0
                (bitwise-and #xFF (arithmetic-shift port -8))
                (bitwise-and #xFF port)
                a1 a2 a3 a4
                0 0 0 0 0 0 0 0))
  (struct-sockaddr-ipv6 (port addr)
    ($define! v (make-bytevector 28 0))
    (bytevector-u8-set! 0 PF_INET6)
    (bytevector-u8-set! 2 (bitwise-and #xFF (arithmetic-shift port -8)))
    (bytevector-u8-set! 3 (bitwise-and #xFF port))
    (bytevector-copy-partial! (list->bytevector addr) 0 16 v 8)
    v)
  (struct-sockaddr-unix (str)
    ($cond
      ((string? str)
        ($define! v (make-bytevector 110 0))
        ($define! n (string->utf8 str))
        (bytevector-u8-set! v 0 PF_UNIX)
        (bytevector-copy-partial! n 0 (bytevector-length n) v 2)
        v)
      ((keyword? str)
        (struct-sockaddr-unix (string-append "\x00;" (keyword->string str))))
      ((eq? str #inert)
        (bytevector PF_UNIX 0))
      (#t
        ($error1 struct-sockaddr-unix "Invalid argument." str))))
  (decode-ip-port (b)
    (bitwise-ior (arithmetic-shift (bytevector-u8-ref b 2) 8)
                 (bytevector-u8-ref b 3))))

($define-ground-lambda! decode-struct-sockaddr (b)
  ($define! af (bytevector-u8-ref b 0))
  ($cond
    ((eq? af PF_INET)
      (list #:ipv4
            (decode-ip-port b)
            (bytevector->list (bytevector-copy-partial b 4 8))))
    ((eq? af PF_INET6)
      (list #:ipv6
            (decode-ip-port b)
            (bytevector->list (bytevector-copy-partial b 8 24))))
    ((eq? af PF_UNIX)
      (list #:unix
            ($let ((len (bytevector-length b)))
              ($cond
                ((=? len 2)
                  #inert)
                ((=? (bytevector-u8-ref b 2) 0)
                  (string->keyword
                    (utf8->string
                      (bytevector-copy-partial b 2 len))))
                (#t
                  (utf8->string
                    (bytevector-copy-partial b 2 len)))))))
    (#t
      ($error1 decode-struct-sockaddr "Unsupported address family" b))))

;; port interface

($define-ground-lambda! socket-binary-input-port (s)
  (open-buffered-binary-input-port (socket-raw-input-port s)))

($define-ground-lambda! socket-binary-output-port (s)
  (open-buffered-binary-output-port (socket-raw-output-port s)))

($define-ground-lambda! socket-textual-input-port (s)
  (open-utf-decoder (socket-raw-input-port s)))

($define-ground-lambda! socket-textual-output-port (s)
  (open-utf-encoder (socket-raw-output-port s)))
