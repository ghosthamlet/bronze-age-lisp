;;;
;;; errors.k
;;;
;;; Error objects (lisp part).
;;;

;;
;; error reporting
;;

($define-ground-lambda! print-error-object (x . rest)
  ($define! port
    ($if (pair? rest)
      (car rest)
      (get-current-output-port)))
  (write-string
    ($if (color-port? port)
      "\x1B;[31;1mERROR:\x1B;[m "
      "ERROR: ")
    port)
  (flush-output-port port)
  ($cond
    ((error-object? x)
      (write-string (error-object-message x) port)
      (write-string "\n    irritants: " port)
      ($cond
        (($and? (integer? (error-object-irritants x))
                (equal? (error-object-message x) "I/O error")
                (keyword? (errno-keyword (error-object-irritants x))))
          (format port "~w [~a]"
            (error-object-irritants x)
            (keyword->string (errno-keyword (error-object-irritants x)))))
        (#t
          (write (error-object-irritants x) port)))
      (write-string "\n    source: " port)
      (write
        ($let1 s (error-object-source x)
          ($if (symbol? s)
            s
            (guess-object-name s #t)))
        port)
       (write-char #\newline port))
    (#t
      (format port "~w\n" x)))
  (flush-output-port port))

;;
;; linux errno codes
;;

($define! errno-list
  ($quote*
    ("EPERM"    1)
    ("ENOENT"   2)
    ("ESRCH"    3)
    ("EINTR"    4)
    ("EIO"      5)
    ("ENXIO"    6)
    ("E2BIG"    7)
    ("ENOEXEC"  8)
    ("EBADF"    9)
    ("ECHILD"  10)
    ("EAGAIN"  11)
    ("ENOMEM"  12)
    ("EACCES"  13)
    ("EFAULT"  14)
    ("ENOTBLK" 15)
    ("EBUSY"   16)
    ("EEXIST"  17)
    ("EXDEV"   18)
    ("ENODEV"  19)
    ("ENOTDIR" 20)
    ("EISDIR"  21)
    ("EINVAL"  22)
    ("ENFILE"  23)
    ("EMFILE"  24)
    ("ENOTTY"  25)
    ("ETXTBSY" 26)
    ("EFBIG"   27)
    ("ENOSPC"  28)
    ("ESPIPE"  29)
    ("EROFS"   30)
    ("EMLINK"  31)
    ("EPIPE"   32)
    ("EDOM"    33)
    ("ERANGE"  34)))

($bind-private! errno-vector
  (make-lisp-vector
    ($let* ((n (apply max (map cadr errno-list)))
            (v (make-vector n #f)))
      (for-each
        ($lambda ((name number))
          (vector-set! v (- number 1) (string->keyword name)))
        errno-list)
      v)))

($define-ground-lambda! errno-keyword (n)
  ($if (<=? 1 n (vector-length errno-vector))
    (vector-ref errno-vector (- n 1))
    #f))
