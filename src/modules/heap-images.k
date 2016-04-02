;;;
;;; heap-images.k
;;;
;;; Save and restore interpreter state.
;;;

(for-each
  ($lambda ((symbol label))
    (bind-private! symbol
      (make-bounded-applicative (list 2 2) (list label) ())))
  ($quote*
    (save-heap-aux "app_save_heap_aux.A2")
    (restore-heap-aux "app_restore_heap_aux.A2")))

($define-ground-lambda! save-heap-image (path . rest)
  ($let1 r
      (save-heap-aux
        ($let* ((b (make-heap-image-header path rest))
                (p (open-binary-output-file path)))
          (write-bytevector b p)
          (flush-output-port p)
          ;; discard cached environment variables
          ($set! private-environment environ #inert)
          p)
        #:original)
    ($cond
      ((integer? r)
        ;; The image was restored by command line option -H. The number
        ;; is an index into the command line argument list.
        ($set! private-environment script-arguments
          (list-tail (get-interpreter-arguments) r))
        #:clone)
      (#t
        ;; restored by (restore-heap-image ...)
        r))))

($define-ground-lambda! restore-heap-image args
  (restore-heap-aux (apply open-heap-image-file args) #:clone))

($define-private-lambda! restore-heap-image/arguments (tail)
  (restore-heap-aux
    (open-heap-image-file (car tail))
    ($letrec
      ;; Find position of the heap image argument on the interpreter
      ;; command line. It will be used for (get-script-arguments)
      ;; in the restored image.
      ((index
        ($lambda (i p q)
          ($if (equal? p q)
            i
            (index (+ i 1) (cdr p) q)))))
      (index 0 (get-interpreter-arguments) tail))))

($define-private-lambda! make-heap-image-header (path rest)
  ($define! t
    (string->utf8
      (with-output-to-string
        ($lambda ()
          (format #t "# interpreter: ~a~%" interpreter-version)))))
  ($define! b
    (make-bytevector 256 (char->integer #\#)))
  (bytevector-copy! t b)
  b)

($define-private-lambda! open-heap-image-file (path . rest)
  ($define! match-version?
    ($lambda ()
      ($define! line (read-line))
      ($and? (string? line)
             ($or? (equal? line (format "# interpreter: ~a" interpreter-version))
                   (match-version?)))))
  ($define! port
    (open-raw-input-file path))
  ;; TODO: depends on default port buffer size
  ($unless (with-input-from-string (utf8->string (read-bytevector port))
                                   match-version?)
    (close-port port)
    (error "Incompatible heap image." path))
  port)
