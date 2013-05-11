;;
;; 06-file-io.k
;;
;; Write data structure to a file and read it back.
;; Repeat five times.
;; The file size is approximately 45 kilobytes.
;;
($define! seed
  (vector
    #t
    ()
    #inert
    12345
    1234567890123456789
    #\c
    "string"
    ((unwrap list) symbol)
    #:keyword))

($define! build-tree
  ($lambda (depth counter)
    ($if (>? depth 0)
      (list
        (build-tree (- depth 1) (+ counter 17))
        (build-tree (- depth 1) (+ counter 29))
        (build-tree (- depth 1) (+ counter 37))
        (build-tree (- depth 1) (+ counter 41))
        (build-tree (- depth 1) (+ counter 57)))
      (list
        counter
        (vector-ref
          seed
          (mod counter (vector-length seed)))))))

($define! data (build-tree 5 0))
($define! (#ignore tmpfile) (get-script-arguments))

($define! write-file
  ($lambda ()
    (with-output-to-file tmpfile
      ($lambda () (write-simple data)))))

($define! read-file
  ($lambda ()
    (with-input-from-file tmpfile read)))

(write-file)
(write-file)
(write-file)
(write-file)
(write-file)

(read-file)
(read-file)
(read-file)
(read-file)
($define! result (read-file))

(write (equal? data result))
