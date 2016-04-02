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
        ($let ((p (open-binary-output-file path))
               (h (string->utf8
                     (with-output-to-string
                       ($lambda ()
                        (display "# saved image textual header TODO\n")))))
              (b (make-bytevector 256)))
          (bytevector-copy! h b)
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

($define-ground-lambda! restore-heap-image (path . rest)
  (restore-heap-aux
    ($let* ((p (open-raw-input-file path))
            (b (read-bytevector p)))
      ;; TODO: depends on default buffer size and no partial read, fix!
      ;; TODO: restore signal handlers
      p)
    #:clone))

($define-private-lambda! restore-heap-image/arguments (tail)
  (restore-heap-aux
    ($let* ((p (open-raw-input-file (car tail)))
            (b (read-bytevector p)))
      ;; TODO: depends on default buffer size and no partial read, fix!
      p)
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
