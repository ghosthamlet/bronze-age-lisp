;;;
;;; dump-heap-image.k
;;;
;;; usage: bronze.bin dump-heap-image.k FILE.heap
;;;
;;; Print contents of saved heap images in human-readable form.
;;;

($define! file-name
  ($match (get-script-arguments)
    ((#ignore file-name) file-name)
    ((script . #ignore)  (format stderr "usage: ~a FILE.heap~%" script) (exit 1))
    (#ignore             (error))))

($define! port
  (open-binary-input-file file-name))

(format #t "input file: ~a~%" file-name)

($define! skip
  ($lambda (n)
    ($dotimes (#ignore n) (read-u8 port))))

($define! read-as-bytevector
  ($lambda (n)
    (with-output-to-bytevector
      ($lambda ()
        ($dotimes (#ignore n) (write-u8 (read-u8 port)))))))

($define! read-as-string
  ($lambda (n)
    (utf8->string (read-as-bytevector n))))

($define! read-le
  ($lambda (bits)
    ($if (positive? bits)
      (bitwise-ior (read-u8 port)
                   (arithmetic-shift (read-le (- bits 8)) 8))
      0)))

($define! $read-print-import!
  ($vau (bits . vars) denv
    ($define! bits (eval bits denv))
    (for-each
      ($lambda (var)
        ($define! val (read-le bits))
        (set! denv var val)
        (format #t "  ~a = #x~x~%" var val))
      vars)))

;; 1. textual header
;;      see modules/heap-images.k

(format #t "header I:~%")
(format #t "  (TODO)~%")
(skip 256)

;; 2. binary header
;;      see "struc saved_heap_header" in modules/heap-images.asm

(format #t "header II:~%")
($read-print-import! 32
  ground-private-base
  ground-private-size
  lisp-heap-base
  lisp-heap-size
  blob-descriptors-base
  blob-descriptors-size
  blob-contents-base
  blob-contents-size
  first-blob
  free-blob
  current-continuation)

;; 3. first pass over the lisp heap
;;    see tagged value description in runtime/types.k

($provide! (mark-pair-address! pair-address?)

  ($define! bitmap
    (make-bytevector (div (+ lisp-heap-size 7) 8)))

  ($define! mark-pair-address!
    ($lambda (a)
      ($define! (i j) (div-and-mod (- a lisp-heap-base) 8))
      (bytevector-u8-set! bitmap i
                          (bitwise-ior (bytevector-u8-ref bitmap i)
                                       (arithmetic-shift 1 j)))))

  ($define! pair-address?
    ($lambda (a)
      ($define! (i j) (div-and-mod (- a lisp-heap-base) 8))
      (not? (zero? (arithmetic-shift (bytevector-u8-ref bitmap i) (negate j)))))))

($dotimes (i (div (+ ground-private-size lisp-heap-size) 4))
  ($let ((x (read-le 32)))
    ($when (=? (bitwise-and x 3) 3)
      ($define! a (bitwise-and (arithmetic-shift x 1) #x7FFFFFF8))
      ;(format #t "~x => ~x ~x +~x~%" x a lisp-heap-base lisp-heap-size)
      ($when (<=? lisp-heap-base a (+ lisp-heap-base lisp-heap-size -1))
        (mark-pair-address! a)))))

;; 4. ground and private environment
;;      see "ground_private_lookup_table" in runtime/data-segments.k

(format #t "ground and private environment values:~%")
(format #t "  (not shown)~%")

;; 5. second pass over the lisp heap
;;    see tagged value description in runtime/types.k

(format #t "lisp heap:~%")
(close-input-port port)
($define! port (open-binary-input-file file-name))
(skip (+ 256 (* 11 4) ground-private-size))

($define! immediate-types
  ($quote*
    (#b00000010 nil)
    (#b00000110 inert)
    (#b00001010 ignore)
    (#b00001110 eof-object)
    (#b00010010 primitive-operative)
    (#b00010110 unbound-dynamic-variable-value)
    (#b00100010 symbol)
    (#b00100110 keyword)
    (#b00101010 string)
    (#b00101110 bytevector)
    (#b01000010 char)
    (#b01000110 boolean)
    (#b01001010 exact-infinity)
    (#b01001110 socket)))

($define! heap-types
  ($quote*
    (#b00000001 vector        () "element")
    (#b00000101 encapsulation ("class") "var")
    (#b00001001 error         ("message" "irritants" "source" "cc" "address" "env" "pad"))
    (#b00001101 critbit       ("index" "child0" "child1"))
    (#b00010001 operative     ("program") "var")
    (#b00010101 applicative   ("program" "underlying") "var")
    (#b00011001 cont          ("program" "parent") "var")
    (#b00011101 environment   ("program" "hashcode" "parent") "key" "val")
    (#b00100001 txt-in        ("env" "close" "read" "peek")  "var")
    (#b00100101 txt-out       ("env" "close" "write" "flush") "var")
    (#b00101001 bin-in        ("env" "close" "read" "peek") "var")
    (#b00101101 bin-out       ("env" "close" "write" "flush") "var")
    (#b00110001 bigint        () "digit")
    (#b00110101 promise       ("node"))
    (#b00111001 library       ("env"))
    (#b00111101 hash-table    ("bucket_count" "vector" "list_lookup" "length" "eq_proc" "hashf" "reconstructor"))))

($define! word->string
  ($lambda (w)
    ($define! lsb (bitwise-and w 3))
    ($define! msb (bitwise-and (arithmetic-shift w -31) 1))
    ($cond
      ((=? lsb 0)
        (format "heap#~x" w))
      ((=? lsb 1)
        (format "fixint#~d"
          (bitwise-ior (arithmetic-shift w -2)
                       (arithmetic-shift (negate msb) 30))))
      ((=? lsb 2)
        ($define! t (bitwise-and w #xFF))
        ($define! a (assoc t immediate-types))
        ($if (null? a)
          (format "immediate-value#~x" w)
          (format "~a#~d" (cadr a) (arithmetic-shift w -8))))
      ((=? lsb 3)
        (format "~apair#~x" ($if (=? msb 1) "m" "i") w)))))

($define! parse-heap-object
  ($lambda (a desc size)
    ($define! print-words
      ($lambda (fields i)
        ($when (<? i (- size 1))
          ($define! w (read-le 32))
          ($if (pair? fields)
            ($sequence
              (format #t " (~a ~a)" (car fields) (word->string w))
              (print-words (cdr fields) (+ i 1)))
            ($sequence
              (format #t " ~a" (word->string w))
              (print-words () (+ i 1)))))))
    (format #t "  ~x ~a (~a words)" a (cadr desc) size)
    (print-words (caddr desc) 0)
    (format #t "~%")))

($define! parse-heap
  ($lambda (i)
    ($define! a (+ i lisp-heap-base))
    ($cond
      ((>=? i lisp-heap-size)
        #inert)
      ((pair-address? a)
        ($let* ((car-field (read-le 32))
                (cdr-field (read-le 32)))
          (format #t "  ~x pair (car ~a) (cdr ~a)~%"
              a (word->string car-field) (word->string cdr-field))
          (parse-heap (+ i 8))))
      (#t
        ($let* ((header (read-le 32))
                (type   (bitwise-and header #xFF))
                (desc   (assoc type heap-types))
                (size   (arithmetic-shift header -8)))
          ($if (null? desc)
            ($sequence
              (format #t "  ~x ~x ??? (~a words)~%" a header size)
              (skip (* 4 (- size 1))))
            (parse-heap-object a desc size))
          (parse-heap (+ i (* 4 size))))))))

(parse-heap 0)

;; 5. blob heap
;;      see runtime/blob-data.asm

(format #t "blob heap:~%")

($define! read-blob-descriptors
  ($lambda (i n max-address max-next descriptors)
    ($if (>=? i n)
      (list max-address max-next descriptors)
      ($let* ((address (read-le 32))
              (next    (read-le 32)))
        (read-blob-descriptors
          (+ i 1)
          n
          (max address max-address)
          (max next max-next)
          ($if (=? address max-address)
            descriptors
            (cons (list i address next) descriptors)))))))

($let ()
  ($define! max-print-size
    20)
  ($define! (descriptors first-index)
    ($let ()
      ($define! nram (div blob-descriptors-size 8))
      ($define! (max-address max-next ds) (read-blob-descriptors 0 nram 0 0 ()))
      (list (sort ds <? cadr) (- max-next nram -1))))
  ($define! print-descriptors
    ($lambda (ds rem)
      ($if ($or? (null? ds) (null? (cdr ds)))
        ($sequence
          (format #t "  (malformed)")
          (skip rem))
        ($let ((((i1 a1 n1) (i2 a2 n2) . #ignore) ds))
          ($define! index (+ i1 first-index))
          ($define! size (- a2 a1))
          ($if (=? index free-blob)
            ($sequence
              (format #t "  ~a #x~x free space (~a bytes)~%" index a1 size)
              (skip rem))
            ($sequence
              (format #t "  ~a #x~x ~w~a (~a bytes~a)~%"
                index a1
                (read-as-string (min size max-print-size))
                ($if (<? size max-print-size) "" "...")
                size
                ($if (=? index first-blob) ", first-blob" ""))
              (skip (- size (min size max-print-size)))
              (print-descriptors (cdr ds) (- rem size))))))))
  (print-descriptors descriptors blob-contents-size))

