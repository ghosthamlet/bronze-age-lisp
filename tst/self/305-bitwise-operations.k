;;;
;;; 305-bitwise-operations.k
;;;
;;; Test bitwise operations on fixints and bigints.
;;;

($define! $eq
  ($vau (e1 e2) denv
    ($let
      ((r1 (protect-eval e1 (make-kernel-standard-environment)))
       (r2 (protect-eval e2 (make-kernel-standard-environment))))
      ($if (equal? r1 r2)
        (pass)
        (fail-with-report
          "bitwise"
          e1
          r1 r2)))))

($define! $eq*
  ($vau (bindings e1 e2) denv
    ($let
      ((r1 (protect-eval (list $let-safe bindings e1) denv))
       (r2 (protect-eval (list $let-safe bindings e2) denv)))
      ($if (equal? r1 r2)
        (pass)
        (fail-with-report
          (list
            ($quote $let)
            (map ($lambda ((l r)) (list l (eval r denv))) bindings)
            ($quote ...))
          e1
          r1 r2)))))

($define! $for
  ($vau ((var a b) . body) denv
    ($let*
      ((a (eval a denv))
       (b (eval b denv))
       (run (eval (list* $lambda (list var) body) denv)))
      ($letrec
        ((aux ($lambda (k) ($when (<=? k b) (run k) (aux (+ k 1))))))
        (aux a)))))

;; integer-length
;;
($eq (integer-length (* 256 256 256 256)) 33)
($eq (map integer-length (list 0 1 -1 7 -7 8 -8)) ; examples
     (list 0 1 0 3 3 4 3))                        ; from SRFI-33

;; arithmetic-shift
;;
($eq (map ($lambda (n) (arithmetic-shift 1 n))
          (list 0 1 2 3 4 5 6 7 8 9))
     (list 1 2 4 8 16 32 64 128 256 512))

($eq (map ($lambda (n) (arithmetic-shift 256 (negate n)))
          (list 0 1 2 3 4 5 6 7 8 9))
     (list 256 128 64 32 16 8 4 2 1 0))

($eq (arithmetic-shift 1 #e+infinity) #e+infinity)
($eq (arithmetic-shift -1 #e+infinity) #e-infinity)
($eq (arithmetic-shift 1 #e-infinity) 0)
($eq (arithmetic-shift -1 #e-infinity) 0)
($eq (arithmetic-shift #e+infinity #e+infinity) #e+infinity)
($eq (arithmetic-shift #e-infinity #e+infinity) #e-infinity)

($eq (arithmetic-shift 1 (negate (arithmetic-shift 1 100))) 0)
($eq (arithmetic-shift (arithmetic-shift 1 100)
                       (negate (arithmetic-shift 1 100)))
     0)

($for (i 0 63)
  ($eq* ((i i))
    (arithmetic-shift (arithmetic-shift 1 i) (negate i))
    1))

($for (i 0 63)
  ($eq* ((i i))
    (list (integer-length (arithmetic-shift 1 i))
          (integer-length (arithmetic-shift -1 i)))
    (list (+ i 1) i)))

($eq (arithmetic-shift -6291456 345)
     -450920175892575979754780274583552709256131049390397415175799866534184132822004821145030207689875590982131515392)
($eq (arithmetic-shift -6291456 -1)
     -3145728)

;; bitwise-not
;;
($eq (map bitwise-not (list -7 -6 -5 -4 -3 -2 -1 0 1 2 3 4 5 6 7))
     (list 6 5 4 3 2 1 0 -1 -2 -3 -4 -5 -6 -7 -8))
($eq (+ 1 (bitwise-not 12345678901234567)) -12345678901234567)

;; bitwise-and, bitwise-ior, bitwise-xor
;;
($eq (bitwise-and #x123456 #xFEDCBA) #x121412)
($eq (bitwise-ior #x123456 #xFEDCBA) #xFEFCFE)
($eq (bitwise-xor #x123456 #xFEDCBA) #xECE8EC)

($eq (bitwise-and #x123456789ABCDEF #xFEDCBA987654321) #x121412181214121)
($eq (bitwise-ior #x123456789ABCDEF #xFEDCBA987654321) #xFEFCFEF8FEFCFEF)
($eq (bitwise-xor #x123456789ABCDEF #xFEDCBA987654321) #xECE8ECE0ECE8ECE)

(summary)
