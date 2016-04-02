;;;
;;; heap-image.k
;;;
;;; usage: bronze.bin heap-image.k
;;;
;;; Demonstrate heap image save and restore.
;;;

($define! image-file
  "heap-image.heap")

($define! value
  ($sequence
    (format #t "Enter any value: ")
    (read)))

($let ((kwd (save-heap-image "heap-image.heap")))
  ($cond
    ((eq? kwd #:original)
      (format #t "The image was saved. Execute~%  bronze.bin -H ~a~%to continue.~%"
              image-file))
    ((eq? kwd #:clone)
      (format #t "The image was restored.~%")
      (format #t "The value is ~w.~%" value)
      (format #t "Script arguments are ~w.~%" (get-script-arguments)))))
