;;;
;;; 313-hash-functions.k
;;;
;;; Test of (hash ...) and (make-hash-function ...)
;;;

;;
;; compatibilty with equal?
;;

($define! $equal?
  ($vau xs denv
    ($define! ys
      (map ($lambda (x) (protect-eval x denv)) xs))
    ($if ($and? (apply equal? (cons "return" (map car ys)))
                (apply equal? (map cadr ys)))
      (pass)
      (fail-with-report "hash function"
        xs ys (list (car xs) ($quote |...|))))))

($let*
  ((cs (list #\a #\b #\c))
   (s1 "abc")
   (s2 (list->string cs))
   (s3 (symbol->string ($quote abc)))
   (s4 (keyword->string #:abc)))
  ($unless (equal? s1 s2 s3 s4) (error))
  ($equal? (hash s1) (hash s2) (hash s3) (hash s4))
  ($equal? (hash s1 123) (hash s2 123) (hash s3 123) (hash s4 123)))

($let*
  ((x1 12345678901234567890)
   (x2 (+ (* 1234567890 10000000000) 1234567890)))
  ($unless (equal? x1 x2) (error))
  ($equal? (hash x1) (hash x2))
  ($equal? (hash x1 123) (hash x2 123)))

($let*
  ((x1 (list (list 1 2) (list 3 4)))
   (x2 (copy-es x1))
   (x3 (copy-es-immutable x1)))
  ($unless (equal? x1 x2 x3) (error))
  ($equal? (hash x1) (hash x2) (hash x3))
  ($equal? (hash x1 123) (hash x2 123) (hash x3 123)))

;;
;; no colisions for "small" inputs
;;

($define! the-eof-object
  (with-input-from-string "" read-char))

($define! small-inputs
  (cons
    the-eof-object
    ($quote* 0 1 -1 2 -2 #t #f #\a #\z #inert #ignore
             () (1) (2) (1 2)
             #:x #:y x y "x" "y")))

($define! for-each-pair
  ($case-lambda
    ((f (x . xs))
      (for-each ($lambda (y) (f x y)) xs)
      (for-each-pair f xs))
    (#ignore
      #inert)))

($define! distinct-hash-values
  ($lambda (n inputs)
    ($define! h (make-hash-function n))
    (for-each-pair
      ($lambda (x y)
        ($unless (eq? x y)
          ($let ((hx (apply h (list x)))
                 (hy (apply h (list y))))
            ($if (=? hx hy)
              ($sequence
                (fail)
                (format #t "  FAIL make-hash-function\n      ~w => ~w, ~w => ~w\n"
                  (list h x) hx
                  (list h y) hy))
              (pass)))))
        inputs)))

(distinct-hash-values 4096 small-inputs)

;;
;; no colisions for values of different types
;;

($define! various-inputs
  ($let (((enc #ignore #ignore) (make-encapsulation-type)))
    (list
      the-eof-object
      (make-environment)
      ($vau #ignore #ignore #inert)
      ($lambda #ignore #ignore #inert)
      (vector 1 2)
      (list 1 2)
      root-continuation
      ($lazy 0)
      (enc 1)
      "a"
      #:a
      ($quote a))))

(distinct-hash-values 4096 various-inputs)

;;
;; Stability of hash values.
;;

($define! same-hash?
  ($lambda (x a b)
    ($if (=? a b)
      (pass)
      (fail-with-report "hash function stability"
        (list hash x)
        (list a b)
        (list a a)))))

($let ()
  ($define! tail (list 1 2 3))
  ($define! test
    ($lambda (n f)
      ($define! x (f (list* f n tail)))
      ($define! b (hash x))
      ($define! #ignore (list-tabulate (* 1000 n) list))
      ($define! c (hash x))
      (same-hash? x b c)
      ($when (positive? n)
        (test (- n 1) f))))
  (test 15 list)
  (test 15 list->vector)
  (test 15 copy-es-immutable))


;;
;; Test vectors from the reference SipHash implementation
;; https://131002.net/siphash/siphash24.c
;;

($define! siphash-test-vectors
  ($quote*
    (#x31 #x0e #x0e #xdd #x47 #xdb #x6f #x72)
    (#xfd #x67 #xdc #x93 #xc5 #x39 #xf8 #x74)
    (#x5a #x4f #xa9 #xd9 #x09 #x80 #x6c #x0d)
    (#x2d #x7e #xfb #xd7 #x96 #x66 #x67 #x85)
    (#xb7 #x87 #x71 #x27 #xe0 #x94 #x27 #xcf)
    (#x8d #xa6 #x99 #xcd #x64 #x55 #x76 #x18)
    (#xce #xe3 #xfe #x58 #x6e #x46 #xc9 #xcb)
    (#x37 #xd1 #x01 #x8b #xf5 #x00 #x02 #xab)
    (#x62 #x24 #x93 #x9a #x79 #xf5 #xf5 #x93)
    (#xb0 #xe4 #xa9 #x0b #xdf #x82 #x00 #x9e)
    (#xf3 #xb9 #xdd #x94 #xc5 #xbb #x5d #x7a)
    (#xa7 #xad #x6b #x22 #x46 #x2f #xb3 #xf4)
    (#xfb #xe5 #x0e #x86 #xbc #x8f #x1e #x75)
    (#x90 #x3d #x84 #xc0 #x27 #x56 #xea #x14)
    (#xee #xf2 #x7a #x8e #x90 #xca #x23 #xf7)
    (#xe5 #x45 #xbe #x49 #x61 #xca #x29 #xa1)
    (#xdb #x9b #xc2 #x57 #x7f #xcc #x2a #x3f)
    (#x94 #x47 #xbe #x2c #xf5 #xe9 #x9a #x69)
    (#x9c #xd3 #x8d #x96 #xf0 #xb3 #xc1 #x4b)
    (#xbd #x61 #x79 #xa7 #x1d #xc9 #x6d #xbb)
    (#x98 #xee #xa2 #x1a #xf2 #x5c #xd6 #xbe)
    (#xc7 #x67 #x3b #x2e #xb0 #xcb #xf2 #xd0)
    (#x88 #x3e #xa3 #xe3 #x95 #x67 #x53 #x93)
    (#xc8 #xce #x5c #xcd #x8c #x03 #x0c #xa8)
    (#x94 #xaf #x49 #xf6 #xc6 #x50 #xad #xb8)
    (#xea #xb8 #x85 #x8a #xde #x92 #xe1 #xbc)
    (#xf3 #x15 #xbb #x5b #xb8 #x35 #xd8 #x17)
    (#xad #xcf #x6b #x07 #x63 #x61 #x2e #x2f)
    (#xa5 #xc9 #x1d #xa7 #xac #xaa #x4d #xde)
    (#x71 #x65 #x95 #x87 #x66 #x50 #xa2 #xa6)
    (#x28 #xef #x49 #x5c #x53 #xa3 #x87 #xad)
    (#x42 #xc3 #x41 #xd8 #xfa #x92 #xd8 #x32)
    (#xce #x7c #xf2 #x72 #x2f #x51 #x27 #x71)
    (#xe3 #x78 #x59 #xf9 #x46 #x23 #xf3 #xa7)
    (#x38 #x12 #x05 #xbb #x1a #xb0 #xe0 #x12)
    (#xae #x97 #xa1 #x0f #xd4 #x34 #xe0 #x15)
    (#xb4 #xa3 #x15 #x08 #xbe #xff #x4d #x31)
    (#x81 #x39 #x62 #x29 #xf0 #x90 #x79 #x02)
    (#x4d #x0c #xf4 #x9e #xe5 #xd4 #xdc #xca)
    (#x5c #x73 #x33 #x6a #x76 #xd8 #xbf #x9a)
    (#xd0 #xa7 #x04 #x53 #x6b #xa9 #x3e #x0e)
    (#x92 #x59 #x58 #xfc #xd6 #x42 #x0c #xad)
    (#xa9 #x15 #xc2 #x9b #xc8 #x06 #x73 #x18)
    (#x95 #x2b #x79 #xf3 #xbc #x0a #xa6 #xd4)
    (#xf2 #x1d #xf2 #xe4 #x1d #x45 #x35 #xf9)
    (#x87 #x57 #x75 #x19 #x04 #x8f #x53 #xa9)
    (#x10 #xa5 #x6c #xf5 #xdf #xcd #x9a #xdb)
    (#xeb #x75 #x09 #x5c #xcd #x98 #x6c #xd0)
    (#x51 #xa9 #xcb #x9e #xcb #xa3 #x12 #xe6)
    (#x96 #xaf #xad #xfc #x2c #xe6 #x66 #xc7)
    (#x72 #xfe #x52 #x97 #x5a #x43 #x64 #xee)
    (#x5a #x16 #x45 #xb2 #x76 #xd5 #x92 #xa1)
    (#xb2 #x74 #xcb #x8e #xbf #x87 #x87 #x0a)
    (#x6f #x9b #xb4 #x20 #x3d #xe7 #xb3 #x81)
    (#xea #xec #xb2 #xa3 #x0b #x22 #xa8 #x7f)
    (#x99 #x24 #xa4 #x3c #xc1 #x31 #x57 #x24)
    (#xbd #x83 #x8d #x3a #xaf #xbf #x8d #xb7)
    (#x0b #x1a #x2a #x32 #x65 #xd5 #x1a #xea)
    (#x13 #x50 #x79 #xa3 #x23 #x1c #xe6 #x60)
    (#x93 #x2b #x28 #x46 #xe4 #xd7 #x06 #x66)
    (#xe1 #x91 #x5f #x5c #xb1 #xec #xa4 #x6c)
    (#xf3 #x25 #x96 #x5c #xa1 #x6d #x62 #x9f)
    (#x57 #x5f #xf2 #x8e #x60 #x38 #x1b #xe5)
    (#x72 #x45 #x06 #xeb #x4c #x32 #x8a #x95)))

($let
  ((key (list->bytevector (iota 16))))
  (map
    ($lambda (n vs)
      ($define! data (list->bytevector (iota n)))
      ($equal? vs
               (bytevector->list (hash-bytevector data key))))
    (iota (length siphash-test-vectors))
    siphash-test-vectors))

(summary)
